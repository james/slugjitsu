module Slugjitsu
  class << self
    attr_accessor :reserved_words
    attr_accessor :max_length
    attr_accessor :downcase
  end
  
  def self.append_features(base)
     base.extend(ClassMethods)
  end

  # creates a dir safe name that is unique to the give scope which is a list of existing names
  def self.dirify(str, scope)
    # Change accented latin characters to their non-accented
    # forms by normalizing the string and then removing 
    # special unicode characters
    str = str.dup
    str.chars.normalize!(:d)
    str.chars.gsub!(/[^\0-\x80]/, '')
    
    reserved_words.each do |word|
      scope << word unless scope.include?(word)
    end

    str.chars.gsub!(/\W+/, ' ')     # all non-word chars to spaces
    str = str.chars[0...max_length] # shorten if over max length
    str.chars.strip!                # ohh la la
    str.chars.downcase! if Slugjitsu.downcase
    str.chars.gsub!(/\ +/, '-')     # spaces to dashes, preferred separator char everywhere
    
    candidate = str
    number = 0 
    
    candidate = "#{str}-#{number = number + 1}" while scope.include?(candidate.to_s)  
    candidate.to_s
  end
  
  # exception thrown if items of a given uri not found
  class URINotFound < ActiveRecord::RecordNotFound
  end
  
  # methods that are added as class methods to ActiveRecord::Base
  module ClassMethods
    def has_slug(field, slug_field=:permalink, options = {})
     options.assert_valid_keys(:scope)
     write_inheritable_attribute("slugjitsu_field".to_sym, field)
     scope = write_inheritable_attribute("slugjitsu_scope".to_sym, options[:scope]) if options.has_key? :scope
     slug_field = write_inheritable_attribute("slugjitsu_slug_field".to_sym, slug_field)
     
     class_eval { include Slugjitsu::InstanceMethods }
     
     before_validation :create_slug
     
     val_opts = if scope
       { :scope => "#{options[:scope].to_s}_id" }
     else
       {}
     end
     
     validates_uniqueness_of slug_field, val_opts
     
    end
  end
  
  module InstanceMethods
    def create_slug
      field = self.send self.class.read_inheritable_attribute(:slugjitsu_field)
      slug_field = self.class.read_inheritable_attribute(:slugjitsu_slug_field)
      slug = send(slug_field)
      write_attribute(slug_field, Slugjitsu::dirify(field, slug_scope)) if field && (slug.nil? || slug.empty?)
    end
    
    def slug_scope
      scope = self.class.read_inheritable_attribute(:slugjitsu_scope)
      slug = self.class.read_inheritable_attribute(:slugjitsu_slug_field)
      
      if scope
        scope_id = send("#{scope.to_s}_id")
        where = "where #{scope.to_s}_id = #{scope_id}"
      else
        where = ''
      end
      
      SlugFinder.new(self.class, where)
    end
  end
  
  class SlugFinder
    def initialize(model, where)
      @model = model
      @where = where
    end
    
    def include?(slug)
      sql = "select 1 from #{@model.table_name} WHERE "
      sql << " #{@where} AND " unless @where.empty?
      sql << "#{@model.read_inheritable_attribute(:slugjitsu_slug_field)} = '#{slug}'"
      prohibited.include?(slug) || @model.connection.select_one(sql)
    end
    
    # Used by slugjitsu to add prohibited words to the scope  
    
    def <<(something)
      prohibited << something
    end
    
    def prohibited
      @prohibited ||= []
    end
  end 
end

Slugjitsu.reserved_words   = %w{new}
Slugjitsu.max_length       = 100
Slugjitsu.downcase         = true
require 'iconv'

module Slugjitsu
  class << self
    attr_accessor :translation_to
    attr_accessor :translation_from
  end
  
  def self.append_features(base)
     base.extend(ClassMethods)
  end

  # creates a dir safe name that is unique to the give scope which is a list of existing names
  def self.dirify(str, scope)
      str = Iconv.iconv(translation_to, translation_from, str).to_s
      str.gsub!(/\W+/, ' ') # all non-word chars to spaces
      str.strip!            # ohh la la
      str.downcase!         #
      str.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
      
      str.sub!(/_(\d+)|$/) {|m| '_' + ($1.to_i.next.to_s || '2')} while scope.include?(str) 
      str
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
      
      self.class.find_by_sql("select #{slug} from #{self.class.table_name} #{where}").collect(&slug)
    end
  end
  
end

Slugjitsu.translation_to   = 'ascii//ignore//translit'
Slugjitsu.translation_from = 'utf-8'
module ActsAsCoded
  def self.included(base)
    base.send :extend, ClassMethods
    base.send :include, InstanceMethods
    
    base.class_eval do
      validates_presence_of :code
      validates_uniqueness_of :code
      referenced_by :code
      named_scope :with_code, lambda { |c| { :conditions => { :code => c } } }
    end
  end

  module InstanceMethods
  end
  
  module ClassMethods
  end
end

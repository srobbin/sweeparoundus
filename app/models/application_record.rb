class ApplicationRecord < ActiveRecord::Base
  include Decoratable

  self.abstract_class = true
end

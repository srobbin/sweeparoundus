require "delegate"

# Base class for all decorators. Wraps a model instance and delegates any
# method the decorator doesn't define to the original object (via Ruby's
# built-in SimpleDelegator). This lets us add display/formatting logic
# without cluttering the model itself.
#
# Usage:
#   area.decorate                          # => AreaDecorator wrapping area
#   area.decorate(session: request.session) # => …with session data available
class ApplicationDecorator < SimpleDelegator
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  attr_reader :session

  def initialize(object, session: nil)
    super(object)
    @session = session || {}
  end

  # Convenience accessor for the unwrapped model instance.
  # Example: decorated_area.object  # => the original Area record
  def object
    __getobj__
  end
end

# Gives any ActiveRecord model a `.decorate` method that wraps it in a
# matching decorator class (e.g. Area -> AreaDecorator). The decorator
# receives the original record plus an optional `session` hash so it can
# access request-specific data like search coordinates.
module Decoratable
  extend ActiveSupport::Concern

  def decorate(session: nil)
    decorator_class.new(self, session: session)
  end

  private

  # Looks up the decorator by naming convention: "Area" -> "AreaDecorator".
  # Uses safe_constantize so we get a clear error instead of a cryptic
  # NameError if someone calls .decorate on a model that has no decorator.
  def decorator_class
    "#{self.class.name}Decorator".safe_constantize ||
      raise(NotImplementedError, "No decorator defined for #{self.class.name}. Expected #{self.class.name}Decorator to exist.")
  end
end

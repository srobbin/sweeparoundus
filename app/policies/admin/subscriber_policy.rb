class Admin::SubscriberPolicy < Admin::BasePolicy
  # ActiveAdmin's Pundit adapter authorizes the `show` action via `show?`, which
  # defaults to false in ApplicationPolicy. The Subscribers screen has a show
  # page (alerts panel), so it must be opted in explicitly.
  def show?
    true
  end

  def destroy?
    true
  end
end

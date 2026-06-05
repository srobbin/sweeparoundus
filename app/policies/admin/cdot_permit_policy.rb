class Admin::CdotPermitPolicy < Admin::BasePolicy
  # ActiveAdmin's Pundit adapter authorizes the `show` action via `show?`, which
  # defaults to false in ApplicationPolicy. The CdotPermits screen has a show
  # page, so it must be opted in explicitly.
  def show?
    true
  end
end

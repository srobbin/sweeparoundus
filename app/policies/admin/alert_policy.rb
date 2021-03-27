class Admin::AlertPolicy < Admin::BasePolicy
  def destroy?
    true
  end
end

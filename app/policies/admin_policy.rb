class AdminPolicy < ApplicationPolicy
  def any?
    user.can_manage_users?
  end
end

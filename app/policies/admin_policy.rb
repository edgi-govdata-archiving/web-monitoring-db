class AdminPolicy < ApplicationPolicy
  def any?
    user.manage_users?
  end
end

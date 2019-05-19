class ApiPolicy < ApplicationPolicy
  def view?
    user.present? && user.view?
  end

  def annotate?
    user.present? && user.annotate?
  end

  def import?
    user.present? && user.import?
  end
end

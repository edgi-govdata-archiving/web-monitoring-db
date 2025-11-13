# frozen_string_literal: true

class ApiPolicy < ApplicationPolicy
  def view?
    Rails.configuration.allow_public_view || (user.present? && user.can_view?)
  end

  def annotate?
    user.present? && user.can_annotate?
  end

  def import?
    user.present? && user.can_import?
  end
end

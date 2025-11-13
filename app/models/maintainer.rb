# frozen_string_literal: true

# Maintainer represents an organization that maintains some web pages. It has
# a name and an optional link to a parent maintainer so there can be a
# hierarchical relationship (e.g. an office of a department of an organization)
class Maintainer < ApplicationRecord
  include UuidPrimaryKey

  has_many :maintainerships, foreign_key: :maintainer_uuid
  has_many :pages, through: :maintainerships

  belongs_to :parent,
             class_name: 'Maintainer',
             foreign_key: :parent_uuid,
             optional: true,
             inverse_of: :children

  has_many :children,
           class_name: 'Maintainer',
           foreign_key: :parent_uuid,
           inverse_of: :parent
end

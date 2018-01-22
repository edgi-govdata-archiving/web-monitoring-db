# Agency represents a government agency that maintains some web pages. It's
# pretty simple and only has a "name" right now, but be more complex or link
# to records in other remote databases later.
class Agency < ApplicationRecord
  include UuidPrimaryKey
  has_and_belongs_to_many :pages,
    foreign_key: 'agency_uuid',
    association_foreign_key: 'page_uuid'
end

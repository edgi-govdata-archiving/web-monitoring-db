# Sites represent a group of pages. While the name might appear to imply it,
# sites are not associated with a particular domain or URL; it's merely an
# organizing tool.
class Site < ApplicationRecord
  include UuidPrimaryKey
  has_and_belongs_to_many :pages,
    foreign_key: 'site_uuid',
    association_foreign_key: 'page_uuid'

  # Sites also have a `versionista_id` field to help manage/deal with renamings
  # in Versionista accounts that we import from. In the far future, we might
  # remove this column.
end

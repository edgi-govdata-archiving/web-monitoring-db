class Maintainership < ApplicationRecord
  belongs_to :maintainer, foreign_key: :maintainer_uuid
  belongs_to :page, foreign_key: :page_uuid
end

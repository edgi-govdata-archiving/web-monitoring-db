class VersionistaVersion < ApplicationRecord
  belongs_to :page, class_name: 'VersionistaPage', inverse_of: :versions
  has_one :previous, class_name: 'VersionistaVersion'
  
  def view_url
    diff_with_previous_url.sub(/:\w+\/?$/, '/')
  end
end

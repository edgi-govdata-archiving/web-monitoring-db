module DeprecatedApiResources
  extend ActiveSupport::Concern

  protected

  def page_resource_json(page, include_versions = false)
    resource = {
      id: page.id,
      url: page.url,
      title: page.title,
      agency: page.agency,
      site: page.site,
      versionista_url: versionista_url_for(page),
      created_at: page.created_at,
      updated_at: page.updated_at
    }
    if include_versions
      resource[:versions] = page.versions.map {|version| version_resource_json(version)}
    else
      resource[:latest] = version_resource_json(page.versions.first)
    end
    resource
  end

  def version_resource_json(version)
    change = version.change_from_previous
    {
      id: version.id,
      page_id: version.page_uuid,
      previous_id: version.previous.try(:id),
      diff_with_previous_url: version.source_metadata['diff_with_previous_url'],
      diff_with_first_url: version.source_metadata['diff_with_first_url'],
      diff_length: version.source_metadata['diff_length'],
      diff_hash: version.source_metadata['diff_hash'],
      versionista_version_id: version.source_metadata['version_id'],
      relevant: true,
      created_at: version.capture_time,
      updated_at: version.updated_at,
      annotations: change.annotations.map {|annotation| annotation_resource_json(annotation)}
    }
  end

  def annotation_resource_json(annotation)
    {
      id: annotation.id,
      created_at: annotation.created_at,
      author: annotation.author.email,
      annotaion: annotation.annotation
    }
  end

  def versionista_url_for(page)
    version = page.versions.first
    version.source_metadata['page_url'] if version.source_type == 'versionista'
  end
end

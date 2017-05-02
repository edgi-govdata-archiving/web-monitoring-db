module PagesHelper
  def versionista_info(version, field)
    if version.is_a? Page
      version = version.versions.find_by(source_type: 'versionista')
      return if version.nil?
    end
    if version.source_type == 'versionista'
      version.source_metadata[field]
    end
  end

  def versionista_version_url(version)
    if version.source_type == 'versionista'
      version.source_metadata['url']
    end
  end

  def comparable?(version)
    version.page.versions.last.id != version.id
  end
end

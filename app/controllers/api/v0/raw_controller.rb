class Api::V0::RawController < Api::V0::ApiController

  def show
    @version ||= Version.find_by(version_hash: params[:id])
    storage_path = Rails.root.join 'tmp/storage/archive'
    path = "#{storage_path}/#{@version.version_hash}"
    mime_type = @version.source_metadata['mime_type']
    send_file(path, type: mime_type, disposition: 'inline')
  end

end

class Api::V0::RawController < Api::V0::ApiController

  def show
    @version ||= Version.find_by(version_hash: params[:id])
    # TODO: only return a local file if a bucket isn't set. Otherwise redirect to bucket
    # TODO: don't hardcode path
    path = '/app/tmp/storage/archive/' + @version.version_hash
    mime_type = @version.source_metadata['mime_type']
    send_file(path, type: mime_type, disposition: 'inline')
  end
end

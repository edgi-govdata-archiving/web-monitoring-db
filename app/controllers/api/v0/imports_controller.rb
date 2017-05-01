class Api::V0::ImportsController < Api::V0::ApiController
  def show
    @import ||= Import.find(params[:id])
    status_code = @import.complete? ? 200 : 202
    render status: status_code, json: {
      data: @import
    }
  end

  def create
    file_key = SecureRandom.uuid
    # FIXME: storage should be encapsulated in a service; we shouldn't care here
    # whether it is S3, the local filesystem, Google, or whatever
    s3 = Aws::S3::Client.new
    s3.put_object(
      bucket: ENV['AWS_WORKING_BUCKET'],
      key: file_key,
      body: request.body,
      acl: 'private',
      content_type: 'application/json'
    )

    @import = Import.create(
      file: file_key,
      user: current_user
    )
    ImportVersionsJob.perform_later(@import)
    show
  end
end

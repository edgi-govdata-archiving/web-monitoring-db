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
    FileStorage.default.save_file(file_key, request.body)

    @import = Import.create(
      file: file_key,
      user: current_user
    )
    ImportVersionsJob.perform_later(@import)
    show
  end
end

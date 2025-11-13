# frozen_string_literal: true

class Api::V0::ImportsController < Api::V0::ApiController
  before_action { authorize :api, :import? }

  def show
    @import ||= Import.find(params[:id])
    status_code = @import.complete? ? 200 : 202
    render status: status_code, json: {
      data: @import
    }
  end

  def create
    raise Api::ReadOnlyError if Rails.configuration.read_only

    update_behavior = params[:update] || :skip
    unless Import.update_behaviors.key?(update_behavior)
      raise Api::InputError, "'#{update_behavior}' is not a valid update behavior. Use one of: #{Import.update_behaviors.join(', ')}"
    end

    @import = Import.create_with_data({
      user: current_user,
      update_behavior:,
      create_pages: boolean_param(:create_pages, default: true),
      skip_unchanged_versions: boolean_param(:skip_unchanged_versions)
    }, request.body)
    ImportVersionsJob.perform_later(@import)
    show
  end
end

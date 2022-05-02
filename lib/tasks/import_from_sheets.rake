require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'

IMPORT_TYPE = 'rake_task_v1'.freeze
OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'Web Monitoring DB Importer'.freeze


desc 'Create annotations from data in analysts’ Google sheets -- only sheet ID & user e-mail are required.'
task :import_annotations_from_sheet, [:sheet_id, :user_email, :tabs, :start_row, :end_row] => [:environment] do |_t, args|
  verbose = ENV.fetch('VERBOSE', nil)
  sheet_id = args[:sheet_id]
  start_row = args.fetch(:start_row, 7).to_i
  end_row = args[:end_row] || ''
  client = sheets_client

  user = User.find_by!(email: args[:user_email])

  tab_count = 0
  annotated_count = 0
  skipped_count = 0
  error_count = 0

  tabs =
    if args[:tabs]
      args[:tabs].split(',').collect(&:strip)
    else
      client.get_spreadsheet(sheet_id).sheets.collect do |sheet|
        sheet.properties.title
      end
    end

  begin
    tabs.each do |tab_title|
      puts "Importing spreadsheet tab '#{tab_title}'"

      rows = client.get_spreadsheet_values(
        sheet_id,
        "#{tab_title}!A#{start_row}:AL#{end_row}"
      ).values

      rows.each_with_index do |row, index|
        # Column 9 is latest-to-base
        begin
          change = change_for_version_url(row[9])
        rescue StandardError => error
          puts "Row #{start_row + index}: #{error.message}"
          error_count += 1
        end
        next unless change

        change.annotate(annotation_data_for_row(row), user)
        annotated_count += 1

        puts "Annotated '#{change.version.page.url}' change '#{change.api_id}'" if verbose
      end

      tab_count += 1
    end
  ensure
    puts ''
    puts 'RESULTS:'
    puts '--------'
    puts "Created #{annotated_count} annotations"
    puts "Skipped #{skipped_count} rows"
    puts "Errored #{error_count} rows"
    puts "In      #{tab_count} spreadsheet tabs"
    puts ''
  end
end

def change_for_version_url(url)
  return nil unless url.present?

  # Handle versionista URLs
  match = /versionista\.com\/\d+\/\d+\/(\d+):(\d+)/.match(url)
  if match
    to_version = Version.find_by!(
      "source_type = 'versionista' AND source_metadata->>'version_id' = ?",
      match[1]
    )
    from_version = Version.find_by!(
      "source_type = 'versionista' AND source_metadata->>'version_id' = ?",
      match[2]
    )
    return Change.between(from: from_version, to: to_version, create: :create)
  end

  # Handle our URLs
  match = /monitoring\.envirodatagov\.org\/page\/[^\/]+\/([^\/.]+)\.\.([^\/.]+)/.match(url)
  if match
    from_version = Version.find(match[1])
    to_version = Version.find(match[2])
    return Change.between(from: from_version, to: to_version, create: :create)
  end

  raise StandardError, "Unknown change URL format: '#{url}'"
end

def annotation_data_for_row(row)
  start_index = 17
  # fields from UI project
  fields = [
    ['indiv_1', :boolean],
    ['indiv_2', :boolean],
    ['indiv_3', :boolean],
    ['indiv_4', :boolean],
    ['indiv_5', :boolean],
    ['indiv_6', :boolean],
    ['repeat_7', :boolean],
    ['repeat_8', :boolean],
    ['repeat_9', :boolean],
    ['repeat_10', :boolean],
    ['repeat_11', :boolean],
    ['repeat_12', :boolean],
    ['sig_1', :boolean],
    ['sig_2', :boolean],
    ['sig_3', :boolean],
    ['sig_4', :boolean],
    ['sig_5', :boolean],
    ['sig_6', :boolean],
    'notes'
  ]

  data = { _importer: IMPORT_TYPE }
  fields.each_with_index do |field, index|
    field_name, field_type = field.is_a?(Array) ? field : [field, :text]

    value = row[start_index + index]
    value = value.present? if field_type == :boolean

    data[field_name] = value
  end

  data
end

def sheets_client
  service = Google::Apis::SheetsV4::SheetsService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize_google
  service
end

def authorize_google
  unless ENV.fetch('GOOGLE_CLIENT_ID', nil) && ENV.fetch('GOOGLE_CLIENT_SECRET', nil)
    raise 'You must have both `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` environment variables set.'
  end

  client_id = Google::Auth::ClientId.new(
    ENV.fetch('GOOGLE_CLIENT_ID', nil),
    ENV.fetch('GOOGLE_CLIENT_SECRET', nil)
  )
  scope = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  token_store = Google::Auth::Stores::FileTokenStore.new(file: Tempfile.new)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in your browser and enter the ' \
         'resulting code after authorization:'
    puts url
    code = $stdin.gets.strip
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id,
      code: code,
      base_url: OOB_URI
    )
  end

  credentials
end

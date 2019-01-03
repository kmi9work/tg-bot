require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'Google Sheets API Ruby Quickstart'.freeze
CREDENTIALS_PATH = "#{Rails.root}/config/gapi-credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "#{Rails.root}/tmp/token.yaml".freeze
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = STDIN.gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

namespace :gapi do
  desc "contacts"
  task :contacts => :environment do
    # Initialize the API
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    # Prints the names and majors of students in a sample spreadsheet:
    spreadsheet_id = '1QLpmS7wYu-8DeQW1psgzOS_-THVVu4UmsHuA_KgzG9s' #pensii.eot.su FormNotification
    spreadsheet_id = '165ORjY-XliCM2h4IkTqPLH93sfVLTn5PtanngnKPwiY' # pensii.eot.su FormEvent
    range = 'A!A1:AA174'
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    puts 'No data found.' if response.values.empty?
    response.values.reverse.each do |row|
      sku = row[0]
      phone = row[1].gsub(/[^\d]+/,'').sub(/^7/,'8')
      email = row[2]
      name = row[3]
      city = row[4]
      region = row[5]
      own_comment = row[6]
      action = row[7]
      system_date = row[8]
      contact = Contact.find_by_sku(sku)
      unless contact
        contact = Contact.find_by_phone(phone)
        unless contact
          Contact.create(
            sku: sku,
            phone: phone,
            email: email,
            name: name,
            city: city,
            region: region,
            own_comment: own_comment,
            action: action,
            system_date: system_date,
            state: 'new'
          )
        else
          puts "Duplicate. SKUs: #{sku}, #{contact.sku}, phone: #{phone};"
        end
      else
      end
      # Print columns A and E, which correspond to indices 0 and 4.
    end
  end

  def handle_day(service, spreadsheet_id, range)
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    puts 'handle_day. No data found.' if response.values.empty?
    count = 0
    response.values.each do |row|
      if row[0].present?
        i = 2
        while row[i].present? and row[i+1].present? 
          duty = Duty.new
          duty.team = row[0].to_i
          duty.leader = row[1]
          duty.day = Date.parse row[i]
          duty.start_hour = row[i+1][0..1].to_i
          duty.save
          count += 1
          i+=2
        end
      end
    end
    count
  end

  def handle_night(service, spreadsheet_id, range)
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    puts 'handle_night. No data found.' if response.values.empty?
    count = 0
    response.values.each do |row|
      if row[0].present?
        duty = Duty.new
        duty.number = row[0]
        duty.team = row[1].to_i
        duty.day = Date.parse row[2]
        duty.start_hour = row[3][0..1].to_i
        duty.leader = row[4] if row[4].present?
        duty.save
        count += 1
      end
    end
    count
  end
  desc "notify"
  task :notify => :environment do
    # Initialize the API
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    # Prints the names and majors of students in a sample spreadsheet:
    spreadsheet_id = '1sZkCwsizO2PCTJ-MnTtsGTklBXN6E88YdeznkcBpD18' #Агентство - расписание дежурств
    range_day = 'День!A1:BA100'
    range_night = 'Ночь!A2:E200'
    Duty.all.destroy_all
    count_day = handle_day(service, spreadsheet_id, range_day)
    count_night = handle_night(service, spreadsheet_id, range_night)
    puts "Day: #{count_day}; Night: #{count_night}"
  end
end


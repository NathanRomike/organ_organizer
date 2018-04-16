require 'json'
require 'pry'

class MockProcessor
  # Constants
  API_URL = 'http://localhost:9292/'
  GET_METHOD = 'GET'
  SILENT_OUTPUT = '--silent'
  PAGE_PARAM = '?page='
  API_KEY_HEADER = "-H 'x-api-key: hello'"
  WRITE_STATUS_CODE = '-w "%{http_code}"'

  ORGANS_ENDPOINT = 'orgs'
  ACCOUNTS_ENDPOINT = 'accounts'
  USERS_ENDPOINT = 'users'

  @output_file = File.new('processed_output.json', 'w')

  def self.make_api_request(path, params = '')
    response = `curl -X #{GET_METHOD} #{API_URL}#{path}#{params} #{API_KEY_HEADER} #{SILENT_OUTPUT} #{WRITE_STATUS_CODE}`
    response_status_code = response[-3..-1] # status code at last 3 characters of response
    case response_status_code
    when '503' # request was unavailable - retry immediately
      make_api_request(path, params)
    when '403' # rate limit reached - wait 30 seconds before retry
      sleep(30)
      make_api_request(path, params)
    when '200' # OK!
      return response[0...-3] # response minus status code
    end
  end

  def self.save_to_file(string_to_store)
    # TODO: maybe add flag parameter(s) to help with formatting - like HEAD_NODE
    @output_file.puts("#{string_to_store}")
  end

  def self.request_all_ids(endpoint)
    # makes a request for the first page
    current_page = 1
    response = make_api_request(endpoint, PAGE_PARAM + current_page.to_s)
    id_hash = JSON.parse(response)
    all_ids_array = id_hash['results']
    total_pages = id_hash['pages']

    # loops through and request all remaining pages
    while current_page < total_pages
      current_page = current_page + 1
      (all_ids_array << JSON.parse(make_api_request(endpoint, PAGE_PARAM + current_page.to_s))['results']).flatten!
    end
    return all_ids_array
  end

  def self.request_all_organs(id_list)
    responses = []
    id_list.each do |id|
      organ_response = make_api_request(ORGANS_ENDPOINT + "/#{id}")
      puts organ_response
      responses << organ_response
    end
    return responses
  end

  list_of_ids = request_all_ids(ORGANS_ENDPOINT)
  all_organs = request_all_organs(list_of_ids)
  all_organs.find_all { |organ| organ['parent_id'].nil? }
  save_to_file(all_organs)

  @output_file.close
end
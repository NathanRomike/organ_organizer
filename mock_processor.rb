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

  def self.save_to_file(json_string)
    output_file = File.new('processed_output.json', 'w')
    output_file.puts("#{json_string}")
    output_file.close
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

  def self.request_all_organs(id_array)
    responses_array = []
    id_array.each do |id|
      organ_response = make_api_request(ORGANS_ENDPOINT + "/#{id}")
      instance_hash = JSON.parse(organ_response)
      responses_array << instance_hash
    end
    return responses_array
  end

  def self.sort_organs(all_organs_array)
    formatted_array = []

    # sole organ parents (without children) are already flat
    sole_parent_organs = all_organs_array.select { |organ| organ['type'] == 'sole' }
    sole_parent_organs.sort_by! { |organ| organ['id'] }

    sole_parent_organs.each do |organ_hash|
      organ_hash.delete('parent_id')
      organ_hash.delete('type')
      formatted_array << organ_hash.flatten
    end

    save_to_file(formatted_array)

    # select organs without a parent and have children organs
    top_parent_organs = all_organs_array.select { |organ| organ['parent_id'].nil? &&  organ['type'] == 'parent' }
    top_parent_organs.sort_by! { |organ| organ['id'] }

    children_parents = all_organs_array.select { |organ| organ['parent_id']}

    # pretty_json = JSON.pretty_generate(formatted_array.to_json).delete! '\\'
    # puts pretty_json

    # null_parent_organs = list_of_organs.select { |organ| organ['parent_id'].nil? }
    # puts "null parents: #{null_parent_organs}"
    # top_parent_organs.map! { |top_organ|  }

  end

  all_organs_id_array = request_all_ids(ORGANS_ENDPOINT)
  all_organs_array = request_all_organs(all_organs_id_array)
  sort_organs(all_organs_array)
end
require 'json'
require 'pry'

class MockProcessor
  # Constants
  API_URL = 'http://localhost:9292/'
  GET_METHOD = 'GET'
  SILENT_OUTPUT = '--silent'
  PAGE_PARAM = '?page='
  API_KEY_HEADER = "-H 'x-api-key: <API_KEY_HERE>'"
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

  def self.save_to_file(json_string)
    @output_file.puts("#{json_string}")
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

  def self.request_all_by_id(id_array, endpoint)
    responses_array = []
    id_array.each do |id|
      response = make_api_request(endpoint + "/#{id}")
      instance_hash = JSON.parse(response)
      responses_array << instance_hash
    end
    return responses_array
  end

  def self.sort_organs(organs_array)
    # sole organ parents (without children) are already flat
    formatted_array = organs_array.select { |organ| organ['type'] == 'sole' }
    formatted_array.sort_by! { |organ| organ['id'] }

    # select organs without a parent (these have children organs)
    top_parent_organs = organs_array.select { |organ| organ['parent_id'].nil? &&  organ['type'] == 'parent' }
    top_parent_organs.sort_by! { |organ| organ['id'] }

    # select organs with a parent organ (these are children organs)
    children_parents = organs_array.select { |organ| !organ['parent_id'].nil? && organ['type'] == 'parent' }
    children_parents.sort_by! { |organ| organ['parent_id'] }

    # loop through the children, add the parent as the key, and children as array
    children_parents.each_with_index do |child_org, index|
      parent_to_child = top_parent_organs.select { |organ| organ['id'] == child_org['parent_id']}
      formatted_array << Array.new([parent_to_child, child_org])
    end
    return JSON[formatted_array]
  end

  organs_id_array = request_all_ids(ORGANS_ENDPOINT)
  organs_array = request_all_by_id(organs_id_array, ORGANS_ENDPOINT)

  # TODO: Add children node to parent organs
  save_to_file(sort_organs(organs_array))

  accounts_id_array = request_all_ids(ACCOUNTS_ENDPOINT)
  accounts_array = request_all_by_id(accounts_id_array, ACCOUNTS_ENDPOINT)
  # TODO: Add each organ's account to an 'account' node
  @output_file.close
end
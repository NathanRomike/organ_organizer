require 'json'

class MockProcessor
  # Constants
  OUTPUT_FILE_NAME = 'processed_output.json'

  # API values
  API_URL = 'http://localhost:9292/'
  GET_METHOD = 'GET'
  SILENT_OUTPUT = '--silent'
  PAGE_PARAM = '?page='
  API_KEY_HEADER = "-H 'x-api-key: <API_KEY_HERE>'"
  WRITE_STATUS_CODE = '-w "%{http_code}"'
  ORGANS_ENDPOINT = 'orgs'
  ACCOUNTS_ENDPOINT = 'accounts'
  USERS_ENDPOINT = 'users'

  # JSON node keys
  ACCOUNTS = 'accounts'
  CHILDREN = 'children'
  ORGANS = 'organs'
  REVENUE = 'revenue'

  # Hash keys
  PARENT_ID = 'parent_id'
  RESULTS = 'results'
  ORG_ID = 'org_id'
  PARENT = 'parent'
  PAGES = 'pages'
  SOLE = 'sole'
  TYPE = 'type'
  ID = 'id'

  @retry_counter = 0

  def self.make_api_request(path, params = '')
    response = `curl -X #{GET_METHOD} #{API_URL}#{path}#{params} #{API_KEY_HEADER} #{SILENT_OUTPUT} #{WRITE_STATUS_CODE}`
    response_status_code = response[-3..-1] # status code at last 3 characters of response
    case response_status_code
    when '200' # OK!
      return response[0...-3] # response minus status code
    when '401' # request was unavailable - retry immediately
      make_api_request(path, params)
    when '403' # rate limit reached - wait 30 seconds before retry
      sleep(30)
      make_api_request(path, params)
    else
      while @retry_counter <= 10 # retry immediately 10 times for all other error codes
        @retry_counter += 1
        make_api_request(path, params)
      end
      abort("Connection to data api failed with response code #{response_status_code}. Please try again!")
    end
  end

  def self.save_to_file(processed_array, file_name = OUTPUT_FILE_NAME, process_json = false)
    if process_json
      formatted_json_string = JSON[{ORGANS => processed_array}]
    end
    output_file = File.new(file_name, 'w')
    output_file.puts("#{formatted_json_string}")
    output_file.close
  end

  def self.request_all_ids(endpoint)
    # make a request for the first page
    current_page = 1
    response = make_api_request(endpoint, PAGE_PARAM + current_page.to_s)
    id_hash = JSON.parse(response)
    all_ids_array = id_hash[RESULTS]
    total_pages = id_hash[PAGES]

    # loop through and request all remaining pages
    while current_page < total_pages
      current_page = current_page + 1
      (all_ids_array << JSON.parse(make_api_request(endpoint, PAGE_PARAM + current_page.to_s))[RESULTS]).flatten!
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

  def self.add_accounts_to_organs(accounts_array, organs_array)
    # iterate through all organs and add an 'accounts' array for each organ
    organs_array.each do |organ|
      organ.merge!({ACCOUNTS => accounts_array.select { |account| account[ORG_ID] == organ[ID] }})
    end
    return organs_array
  end

  def self.calculate_organ_revenue(organs_with_accounts)
    organs_with_accounts.each do |organ|
      total_revenue = 0
      organ[ACCOUNTS].each do |account|
        total_revenue += account[REVENUE]
      end
      organ.merge!({REVENUE => total_revenue})

      # TODO: add the support score after children have been flattened
      # support_score = (total_revenue/50000) + 1
      # organ.merge!({'support_score' => support_score})
    end
    return organs_with_accounts
  end

  def self.sort_organs(organs_array)
    # sole organ parents (without children) are already flat
    formatted_array = organs_array.select { |organ| organ[TYPE] == SOLE }
    # TODO: add null to the 'children' array when no children or remove 'children' node

    # select organs without a parent (these might have children organs)
    grandparent_organs = organs_array.select { |organ| organ[PARENT_ID].nil? &&  organ[TYPE] == PARENT }

    # select organs with a parent organ (these are children organs)
    parents_with_children = organs_array.select { |organ| !organ[PARENT_ID].nil? && organ[TYPE] == PARENT }

    # loop through the child organs with children
    parents_with_children.each do |organ|
      # create an array of any children for this organ, merge this new array of 'children' into this organ's node
      organ.merge!({CHILDREN => parents_with_children.select { |child| child[PARENT_ID] == organ[ID] }})
    end

    formatted_array += parents_with_children # combine sole organs with processed parents

    # loop through grandparent organs and add any children
    grandparent_organs.each do |parent|
      parent.merge!({CHILDREN => parents_with_children.select { |child| child[PARENT_ID] == parent[ID] }})
    end

    formatted_array += grandparent_organs  # combine sole + parent organs with grandparent organs
    formatted_array.sort_by! { |organ| organ[ID] }
    return formatted_array
  end

  organs_id_array = request_all_ids(ORGANS_ENDPOINT)
  organs_array = request_all_by_id(organs_id_array, ORGANS_ENDPOINT)

  accounts_id_array = request_all_ids(ACCOUNTS_ENDPOINT)
  accounts_array = request_all_by_id(accounts_id_array, ACCOUNTS_ENDPOINT)

  organs_with_accounts = add_accounts_to_organs(accounts_array, organs_array)
  organs_with_revenue = calculate_organ_revenue(organs_with_accounts)

  sorted_organs = sort_organs(organs_with_revenue)

  save_to_file(sorted_organs)
end
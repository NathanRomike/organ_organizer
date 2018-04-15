require 'json'

class MockProcessor
  # Constants
  API_URL = 'http://localhost:9292/'
  HTTP_METHOD = 'GET'
  SILENT_OUTPUT = '--silent'
  PAGE_PARAM = '?page='

  ORGANS_ENDPOINT = 'orgs'
  ACCOUNTS_ENDPOINT = 'accounts'
  USERS_ENDPOINT = 'users'

  @output_file = File.new('processed_output.json', 'w')

  def self.make_api_request(path, params = '')
    headers = "-H 'x-api-key: hello'"
    status_flag = '-w "%{http_code}"'
    response = `curl -X #{HTTP_METHOD} #{API_URL}#{path}#{params} #{headers} #{SILENT_OUTPUT} #{status_flag}`

    response_code = response[-3..-1]

    # TODO: figure out a better way to avoid rate limit and 503s
    # I'm thinking instant retries for 503s and minute delay after rate limit
    # if (status_code != 200) {sleep for a minute - then make_api_request with same params}
    sleep(0.3)
    # status_code = response.split('^[0-9]')

    puts response
    return response[0...-3]
  end

  def self.save_to_file(json)
    # TODO: maybe add flag parameter(s) to help with formatting - like HEAD_NODE
    @output_file.puts("#{json}")
  end

  def self.request_all_ids(endpoint)
    # make a request for the first page
    current_page = 1
    response = make_api_request(endpoint, PAGE_PARAM + current_page.to_s)
    id_hash = JSON.parse(response)
    all_ids_array = id_hash['results']
    total_pages = id_hash['pages']

    # loop through and request all remaining pages
    while current_page < total_pages
      current_page = current_page + 1
      all_ids_array << JSON.parse(make_api_request(endpoint, PAGE_PARAM + current_page.to_s))['results']
    end

    return all_ids_array
  end

  save_to_file('{"' + ORGANS_ENDPOINT + '":[' + request_all_ids(ORGANS_ENDPOINT).to_s.delete('[]') + ']},')

  @output_file.close
end
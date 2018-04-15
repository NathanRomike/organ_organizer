require 'json'

class MockProcessor
  # Constants
  API_URL = 'http://localhost:9292/'
  HTTP_METHOD = 'GET'
  SILENT_OUTPUT = '2>/dev/null'

  @output_file = File.new('processed_output.json', 'w')

  def self.make_api_request(path, params)
    headers = "-H 'x-api-key: hello'"
    `curl -X #{HTTP_METHOD} #{API_URL}#{path}#{params} #{headers} #{SILENT_OUTPUT}`
  end

  def self.save_to_file(json)
    @output_file.puts(json)
  end

  def self.read_response(path, response)
    response_hash = JSON.parse(response)

    # The "results" array is unique to requests for IDs
    id_array = response_hash['results']
    if id_array
      total_pages = response_hash['pages']
      current_page = response_hash['page']
      puts "Total number of pages: #{total_pages}, Currently on page ##{current_page}"

      id_array = id_array.sort
      id_array.each do |id|
        puts "Processing request for ID: #{id}"
        save_to_file(make_api_request("#{path}/#{id}", '?page=1'))
      end

    else
      individual_name = response_hash['name']
      puts "Hello #{individual_name}"
    end
  end

  path = 'orgs'
  params = '?page=1'
  response = make_api_request(path, params)

  save_to_file(response)
  read_response(path, response)
  @output_file.close
end
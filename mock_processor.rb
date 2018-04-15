require 'json'

class MockProcessor

  def self.create_api_request(params, path)
    http_method = 'GET'
    uri = 'http://localhost:9292/'
    headers = "-H 'x-api-key: hello'"
    silence = '2>/dev/null'
    `curl -X #{http_method} #{uri}#{path}#{params} #{headers} #{silence}`
  end

  def self.save_to_file(json)
    out_file = File.new('processed_output.json', 'w')
    out_file.puts(json)
    out_file.close
  end

  path = 'orgs'
  params = '?page=1'
  response = create_api_request(params, path)

  save_to_file(response)

end
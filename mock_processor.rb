require 'json'

class MockProcessor

  def self.create_api_request(params, path)
    http_method = 'GET'
    uri = 'http://localhost:9292/'
    headers = "-H 'x-api-key: hello'"
    silence = '2>/dev/null'
    `curl -X #{http_method} #{uri}#{path}#{params} #{headers} #{silence}`
  end

  path = 'orgs'
  params = '?page=2'
  response = create_api_request(params, path)
  puts JSON.parse(response)
end
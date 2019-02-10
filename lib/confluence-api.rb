# frozen_string_literal: true

def percentage(counter, total)
  "#{counter.to_s.rjust(total.to_s.length, ' ')}/#{total} #{(counter * 100 / total).floor.to_s.rjust(3, ' ')}%"
end

def confluence_get_spaces
  url = "#{API}/space"
  results = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    body = JSON.parse(response.body)
    results = body['results']
    puts "GET url='#{url}' => OK"
  rescue => error
    puts "GET url='#{url}' => NOK error='#{error}'"
  end
  results
end

# id, key, name, type, status
def confluence_get_space(name)
  confluence_get_spaces.detect { |space| space['name'] == name }
end

@space = confluence_get_space(SPACE)
if @space
  puts "Found space='#{SPACE}' => OK"
else
  puts "Cannot find space='#{SPACE}' => exit"
  exit
end


# GET wiki/rest/api/content/{id}?expand=body.storage
def confluence_get_content(id)
  result = nil
  url = "#{API}/content/#{id}?expand=body.storage"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "GET url='#{url}' => OK"
  rescue => error
    puts "GET url='#{url}' => NOK error='#{error}'"
  end
  result
end

# GET wiki/rest/api/content/{id}?expand=version
def confluence_get_version(id)
  result = nil
  url = "#{API}/content/#{id}?expand=version"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "GET url='#{url}' => OK"
  rescue => error
    puts "GET url='#{url}' => NOK error='#{error}'"
  end
  result
end

# POST wiki/rest/api/content
# {
#   "type": "page",
#   "title": <TITLE>,
#   "space": { "key": <KEY> },
#   "ancestors": [
#     {
#       "id": @parent_id
#     }
#   ],
#   "body": {
#     "storage": {
#       "value": <CONTENT>,
#       "representation": "storage"
#     }
#   }
# }
#
def confluence_create_page(key, title, content, parent_id)
  result = nil
  payload = {
    "type": 'page',
    "title": title,
    "space": { "key": key },
    "body": {
      "storage": {
        "value": content,
        "representation": 'storage'
      }
    }
  }
  if parent_id
    payload['ancestors'] = [{ "id": parent_id }]
  end
  payload = payload.to_json
  url = "#{API}/content"
  # { 'X-Atlassian-Token': 'no-check' }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "POST url='#{url}' title='#{title}' => OK"
  rescue => error
    puts "POST url='#{url}' title='#{title}' => NOK error='#{error}'"
  end
  result
end

# PUT wiki/rest/api/content/{id}
# {
#   "type": "page",
#   "space": { "key": <KEY> },
#   "body": {
#     "storage": {
#       "value": <CONTENT>,
#       "representation": "storage"
#     }
#   }
# }
#
def confluence_update_page(key, id, title, content, counter, total)

  result = nil
  result_get_version = confluence_get_version(id)
  return nil unless result_get_version
  version = result_get_version['version']['number']

  pct = percentage(counter, total)
  payload = {
    "title": title,
    "type": 'page',
    "space": { "key": key },
    "version": { "number": version + 1 },
    "body": {
      "storage": {
        "value": content,
        "representation": 'storage'
      }
    }
  }
  payload = payload.to_json
  url = "#{API}/content/#{id}"
  begin
    response = RestClient::Request.execute(method: :put, url: url, payload: payload, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "#{pct} PUT url='#{url}' id='#{id}' => OK"
  rescue => error
    puts "#{pct} PUT url='#{url}' id='#{id}' => NOK error='#{error}'"
  end
  result
end

# POST /wiki/rest/api/content/{id}/child/attachment
# {
#   multipart: true,
#   file: @file.txt
# }
def confluence_create_attachment(page_id, filepath, counter, total)
  result = nil
  pct = percentage(counter, total)
  payload =
    {
      multipart: true,
      file: File.new(filepath, 'rb')
    }
  url = "#{API}/content/#{page_id}/child/attachment"
  headers = {
    'Authorization': "Basic #{Base64.encode64("#{EMAIL}:#{PASSWORD}")}",
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'X-Atlassian-Token': 'nocheck'
  }
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: headers)
    result = JSON.parse(response.body)
    puts "#{pct} POST url='#{url}' page_id='#{page_id}' filepath='#{filepath}' => OK"
  rescue => error
    puts "#{pct} POST url='#{url}' page_id='#{page_id}' filepath='#{filepath}' => NOK error='#{error}'"
  end
  result
end

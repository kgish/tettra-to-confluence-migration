# frozen_string_literal: true

load './lib/common.rb'

@categories_tree = nil
@offset_to_item = {}
@created_pages = []
@miscellaneous = []

def show_categories(categories_tree)
  categories_tree.each do |c|
    if c[:type] == 'page'
      puts "#{c[:offset]} #{c[:type]} '#{c[:name]}' #{c[:id]} #{c[:url]}"
    else
      folders = c[:folders].length
      pages = c[:pages].length
      puts "#{c[:offset]} #{c[:type]} '#{c[:name]}' #{c[:id]} #{c[:url]} folders: #{folders}, pages: #{pages}"
      if folders.positive?
        show_categories(c[:folders])
      end
      if pages.positive?
        show_categories(c[:pages])
      end
    end
  end
end

def sanity_check
  found = {}
  duplicates = []
  pages = Dir["#{DATA}/*.html"].map { |page| page.gsub(%r{^data/|.html$}, '') }.each { |name| found[name] = false }
  # header = offset|type|name|id|url
  CSV.foreach(LOGFILE, headers: true, header_converters: :symbol, col_sep: '|') do |row|
    type = row[:type]
    unless %r{category|folder|page}.match?(type)
      puts "Unknown type='#{type}': must be 'category', 'folder' or 'page' => EXIT"
      exit
    end
    next unless type == 'page'
    name = row[:id]
    if found[name]
      # Already found, add to duplicates
      duplicates << name
    else
      # Mark as found
      found[name] = true
    end
  end
  pages.each { |page| @miscellaneous << page unless found[page] }
  unless duplicates.empty?
    puts "\nDuplicates #{duplicates.length}:"
    duplicates.each { |page| puts "* #{page}" }
    puts "\nSanity check => NOK (duplicates detected)\n"
    exit
  end
  unless @miscellaneous.empty?
    puts "\nTotal miscellaneous: #{@miscellaneous.length}"
    @miscellaneous.sort.each { |page| puts "* #{page}" }
  end
end

def build_categories_tree
  categories = []
  list = []

  # header = offset|type|name|id|url
  CSV.foreach(LOGFILE, headers: true, header_converters: :symbol, col_sep: '|') do |row|
    list << {
      offset: row[:offset],
      type: row[:type],
      name: row[:name],
      id: row[:id],
      url: row[:url],
    }
  end

  list.each do |item|
    offset = item[:offset]
    type = item[:type]
    name = item[:name]
    id = item[:id]
    url = item[:url]
    offsets = offset.split('-')
    count = offsets.length
    if count == 1
      categories << {
        offset: offset,
        type: type,
        name: name,
        id: id,
        url: url,
        folders: [],
        pages: []
      }
    elsif count == 2
      category = categories.detect { |c| c[:offset] == offsets[0] }
      if category
        parent = categories[offsets[0].to_i]
        if type == 'folder'
          parent[:folders] << {
            offset: offset,
            type: type,
            name: name,
            id: id,
            url: url,
            folders: [],
            pages: []
          }
        elsif type == 'page'
          parent[:pages] << {
            offset: offset,
            type: type,
            name: name,
            id: id,
            url: url,
          }
        else
          puts "Unknown type for #{item.inspect}"
          exit
        end
      else
        puts "Unknown category for #{item.inspect}"
        exit
      end
    elsif count == 3
      category = categories.detect { |c| c[:offset] == offsets[0] }
      if category
        parent = category[:folders][offsets[1].to_i]
        if type == 'folder'
          parent[:folders] << {
            offset: offset,
            type: type,
            name: name,
            id: id,
            url: url,
            folders: [],
            pages: []
          }
        elsif type == 'page'
          parent[:pages] << {
            offset: offset,
            type: type,
            name: name,
            id: id,
            url: url,
          }
        else
          puts "Unknown type for #{item.inspect}"
          exit
        end
      else
        puts "Unknown category for #{item.inspect}"
        exit
      end
    else
      puts "Count = #{count} => SKIP"
    end
  end
  categories
end

def confluence_get_spaces
  url = "#{API}/space"
  results = nil
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    body = JSON.parse(response.body)
    results = body['results']
    puts "GET #{url} => OK"
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
  end
  results
end

# id, key, name, type, status
def confluence_get_space(name)
  confluence_get_spaces.detect { |space| space['name'] == name }
end

def confluence_get_content(id)
  result = nil
  url = "#{API}/content/#{id}?expand=body.storage"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "GET #{url} => OK"
  rescue => error
    if error.response
      response = JSON.parse(error.response)
      status_code = response['statusCode']
      message = response['message']
      puts "GET #{url} title='#{title}' => NOK status_code='#{status_code}', message='#{message}'"
    else
      puts "GET #{url} => NOK error='#{error}'"
    end
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
#       "id": @parentId
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
def confluence_create_page(key, title, content, parentId)
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
  if parentId
    payload["ancestors"] = [{ "id": parentId }]
  end
  payload = payload.to_json
  url = "#{API}/content"
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: HEADERS)
    result = JSON.parse(response.body)
    puts "POST #{url} title='#{title}' => OK"
  rescue => error
    if error.response
      response = JSON.parse(error.response)
      status_code = response['statusCode']
      message = response['message']
      puts "POST #{url} title='#{title}' => NOK status_code='#{status_code}', message='#{message}'"
    else
      puts "POST #{url} => NOK error='#{error}'"
    end
  end
  result
end

def get_all_links
  links = []
  files = Dir["#{DATA}/*.html"]
  files.each do |file|
    counter = 0
    content = File.read(file)
    m = %r{^<html><head><title>(.*?)</title></head><body>(.*)</body></html>$}.match(content)
    title = m[1]
    filename = file.sub(%r{^#{DATA}/}, '')

    # <img src="https://tettra-production.s3.us-west-2.amazonaws.com/teams/37251/users/88716/y5TaEh2...9ZDIO.png" alt="..." />
    content.scan(/<img src="(.*?)"/).each do |match|
      value = match[0]
      next unless %r{^https?://tettra-production.s3}.match?(value)
      counter += 1
      links << {
        counter: counter,
        filename: filename,
        title: title,
        tag: 'image',
        page: '',
        value: value
      }
    end

    # <a href="https://app.tettra.co/teams/[COMPANY]/pages/(page)">
    content.scan(/<a href="(.*?)"/).each do |v|
      value = v[0]
      p = value.match(%r{^https?://app.tettra.co/teams/#{COMPANY}/pages/(.*)$})
      next unless p
      page = p[1]
      counter += 1
      links << {
        counter: counter,
        filename: filename,
        title: title,
        tag: 'anchor',
        page: page,
        value: value
      }
    end
  end

  puts "\nLinks #{links.length}"
  unless links.length.zero?
    links.each do |l|
      if l[:counter] == 1
        puts "* #{l[:filename]} '#{l[:title]}'"
      end
      puts "  #{l[:counter].to_s.rjust(2, '0')} #{l[:tag]} #{l[:page]} #{l[:value]}"
    end
  end
  puts
  write_csv_file('links.csv', links)
end

def download_image(url, count, total)
  filepath = "#{IMAGES}/#{File.basename(url)}"
  puts "#{count.to_s.rjust(total.to_s.length, ' ')}/#{total} #{(count * 100 / total).floor.to_s.rjust(3, ' ')}% #{url}"
  if File.exist?(filepath)
    puts 'File already exists => SKIP'
    return
  end
  begin
    content = RestClient::Request.execute(method: :get, url: url)
    IO.binwrite(filepath, content)
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'GET', url)
  end
end

def download_images
  links = csv_to_array('links.csv')
  images = links.filter { |link| link['tag'] == 'image' }
  total = images.length
  puts "\nDownloading #{total} images"
  images.each_with_index do |image, index|
    download_image(image['value'], index + 1, total)
  end
end

def get_title_and_body(id)
  files = Dir["#{DATA}/*.html"]
  files.each do |file|
    content = File.read(file)
    m = %r{^<html><head><title>(.*?)</title></head><body>(.*)</body></html>$}.match(content)
    title = m[1]
    body = m[2]
    filename = file.sub(%r{^#{DATA}/}, '')
  end
end

def build_offset_to_item(categories_tree, offset_to_item)
  categories_tree.each do |c|
    offset_to_item[c[:offset]] = c
    build_offset_to_item(c[:folders], offset_to_item) if c[:folders] && c[:folders].length.positive?
    build_offset_to_item(c[:pages], offset_to_item) if c[:pages] && c[:pages].length.positive?
  end
  offset_to_item
end

def get_parent(offset)
  if offset.nil? || !offset.is_a?(String) || offset.length.zero?
    puts 'get_parent() invalid offset => EXIT'
    exit
  end
  offsets = offset.split('-')
  return nil if offsets.length == 1
  offsets.pop
  @offset_to_item[offsets.join('-')]
end

def get_parent_id(parent)
  found = @created_pages.find { |page| page[:result] == 'OK' && page[:offset] == parent[:offset] }
  found ? found[:id] : nil
end

def create_page_item(title, body, offset, parent)
  parentId = get_parent_id(parent)
  result = confluence_create_page(@space['key'], title, body, parentId)
  @created_pages <<
    if result
      {
        result: 'OK',
        filename: filename,
        title: title,
        id: result['id'],
        offset: offset
      }
    else
      {
        result: 'NOK',
        filename: filename,
        title: title,
        id: 0,
        offset: offset
      }
    end
end

def create_page(c)
  title = nil
  body = nil

  parent = get_parent(c[:offset])
  if parent
    puts "#{parent[:offset]} '#{parent[:name]}' ::"
  else
    puts 'No parent ::'
  end
  puts "#{c[:offset]} #{c[:type]} '#{c[:name]}' #{c[:id]} #{c[:url]}"

  if ['category', 'folder'].include?(c[:type])
    title = c[:name]
    body = ''
  else
    filename = "#{DATA}/#{c[:id]}.html"
    unless File.exists?(filename)
      puts "create_page() file '#{filename}' does not exit => EXIT"
      exit
    end

    content = File.read(filename)
    m = %r{^<html><head><title>(.*?)</title></head><body>(.*)</body></html>$}.match(content)
    title = m[1]
    body = m[2]
    unless title && body
      puts "create_page() file '#{filename}' has invalid title and/or body => SKIP"
      return
    end
  end
  create_page_item(title, body, c[:offset], parent)
end

def create_pages(categories_tree)
  categories_tree.each do |c|
    create_page(c)
    create_pages(c[:folders]) if c[:folders] && c[:folders].length.positive?
    create_pages(c[:pages]) if c[:pages] && c[:pages].length.positive?
  end
  write_csv_file('created-pages.csv', @created_pages)
end

def upload_images

end

def handle_miscellaneous
  puts "\nhandle_miscellaneous() => #{@miscellaneous.length}"
  # @miscellaneous.each do |id|
  #
  # end
end

@space = confluence_get_space(SPACE)
if @space
  puts "Found space='#{SPACE}' => OK"
else
  puts "Cannot find space='#{SPACE}' => exit"
  exit
end

@categories_tree = build_categories_tree
show_categories(@categories_tree)
@offset_to_item = build_offset_to_item(@categories_tree, @offset_to_item)
sanity_check
# get_all_links
#download_images
puts
create_pages(@categories_tree)
upload_images
handle_miscellaneous

puts "\nDone!"

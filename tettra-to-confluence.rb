# frozen_string_literal: true

load './lib/common.rb'

@categories_tree = nil
@offset_to_item = {}

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
  not_found = []
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
  pages.each { |page| not_found << page unless found[page] }
  unless not_found.empty?
    puts "\nNot found #{not_found.length}:"
    not_found.sort.each { |page| puts "* #{page}" }
  end
  unless duplicates.empty?
    puts "\nDuplicates #{duplicates.length}:"
    duplicates.each { |page| puts "* #{page}" }
  end
  if !not_found.empty? || !duplicates.empty?
    puts "\nSanity check => NOK\n"
    # exit
  else
    puts "\nSanity check => OK\n"
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
#     "type": "page",
#     "title": <TITLE>,
#     "space": { "key": <KEY> },
#     "body": {
#         "storage": {
#             "value": <CONTENT>,
#             "representation": "storage"
#         }
#     }
# }
#
def confluence_create_page(key, title, content)
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
  }.to_json
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
  filepath = "#{IMAGES}/#{SecureRandom.urlsafe_base64}.gif"
  puts "#{count.to_s.rjust(total.to_s.length, ' ')}/#{total} #{(count*100/total).floor.to_s.rjust(3, ' ')}% #{url}"
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

# while File.exist?(filepath)
#   nr += 1
#   goodbye("Failed for filepath='#{filepath}', nr=#{nr}") if nr > 9999
#   extname = File.extname(filepath)
#   basename = File.basename(filepath, extname)
#   dirname = File.dirname(filepath)
#   basename = basename.sub(/\.\d{4}$/, '')
#   filename = "#{basename}.#{nr.to_s.rjust(4, '0')}#{extname}"
#   filepath = "#{dirname}/#{filename}"
# end
#
# begin
#   content = RestClient::Request.execute(method: :get, url: url, headers: ASSEMBLA_HEADERS)
#   IO.binwrite(filepath, content)
#   # @jira_attachments << {
#   attachment = {
#     created_at: created_at,
#     created_by: created_by,
#     assembla_attachment_id: id,
#     assembla_ticket_id: assembla_ticket_id,
#     filename: filename,
#     content_type: content_type
#   }
#   write_csv_file_append(attachments_jira_csv, [attachment], counter == 1)
# rescue RestClient::ExceptionWithResponse => e
#   rest_client_exception(e, 'GET', url)
# end

def get_links
  results = []
  files = Dir["#{DATA}/*.html"]
  files.each do |file|
    content = File.read(file)
    m = %r{^<html><head><title>(.*?)</title></head><body>(.*)</body></html>$}.match(content)
    title = m[1]
    body = m[2]
    filename = file.sub(%r{^#{DATA}/}, '')
    if title && body
      puts "#{file} title='#{title}' => OK"
      result = confluence_create_page(space['key'], title, body)
      results << if result
                   {
                     result: 'OK',
                     filename: filename,
                     title: title,
                     id: result['id']
                   }
                 else
                   {
                     result: 'NOK',
                     filename: filename,
                     title: title,
                     id: 0
                   }
                 end
    else
      puts "#{file} title='#{title}' => NOK"
      results << {
        result: 'BAD',
        filename: filename,
        title: title,
        id: 0
      }
    end
  end

  write_csv_file('results.csv', results)
end

def build_offset_to_item(categories_tree, offset_to_item)
  categories_tree.each do |c|
    offset_to_item[c[:offset]] = c
    build_offset_to_item(c[:folders], offset_to_item) if c[:folders] && c[:folders].length.positive?
    build_offset_to_item(c[:pages], offset_to_item) if c[:pages] && c[:pages].length.positive?
  end
  return offset_to_item
end

def get_parent(offset)
  if offset.nil? || !offset.is_a?(String) || offset.length.zero?
    puts 'get_parent() invalid offset => EXIT'
    exit
  end
  offsets = offset.split('-')
  offsets.pop
  offsets.length > 1 ? @offset_to_item[offsets.join('-')] : nil
end

def create_confluence_page(c)
  parent = get_parent(c[:offset])
  p = parent ? "#{parent[:offset]} '#{parent[:name]} :: " : ''
  puts "#{p}#{c[:offset]} #{c[:type]} '#{c[:name]}' #{c[:id]} #{c[:url]}"
end

def create_confluence_pages(categories_tree)
  categories_tree.each do |c|
    create_confluence_page(c)
    create_confluence_pages(c[:folders]) if c[:folders] && c[:folders].length.positive?
    create_confluence_pages(c[:pages]) if c[:pages] && c[:pages].length.positive?
  end
end

space = confluence_get_space(SPACE)
if space
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
download_images
create_confluence_pages(@categories_tree)

puts "\nDone!"

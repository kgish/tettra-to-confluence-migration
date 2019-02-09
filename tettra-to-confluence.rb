# frozen_string_literal: true

load './lib/common.rb'
load './lib/confluence-api.rb'

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
    unless /category|folder|page/.match?(type)
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
    @miscellaneous.sort!
    @miscellaneous.each { |page| puts "* #{page}" }
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
    n = offsets.length
    if n == 1
      categories << {
        offset: offset,
        type: type,
        name: name,
        id: id,
        url: url,
        folders: [],
        pages: []
      }
    elsif n == 2
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
    elsif n == 3
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
      puts "Count = #{n} => SKIP"
    end
  end
  categories
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

def download_image(url, counter, total)
  filepath = "#{IMAGES}/#{File.basename(url)}"
  pct = percentage(counter, total)
  return if File.exist?(filepath)
  begin
    content = RestClient::Request.execute(method: :get, url: url)
    IO.binwrite(filepath, content)
    puts "#{pct} GET url=#{url} => OK"
  rescue => error
    puts "#{pct} GET url=#{url} => NOK error='#{error.inspect}'"
  end
end

def download_all_images
  links = read_csv_file('links.csv')
  images = links.filter { |link| link['tag'] == 'image' }
  total = images.length
  puts "\nDownloading #{total} images"
  images.each_with_index do |image, index|
    download_image(image['value'], index + 1, total)
  end
  puts "Done!\n"
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
  return nil if parent.nil?
  found = @created_pages.detect { |page| page[:result] == 'OK' && page[:offset] == parent[:offset] }
  found ? found[:id] : nil
end

def create_page_item(filename, title, body, offset, parent)
  parent_id = get_parent_id(parent)
  result = confluence_create_page(@space['key'], title, body, parent_id)
  @created_pages <<
    if result
      {
        result: 'OK',
        id: result['id'],
        offset: offset,
        title: title,
        filename: filename
      }
    else
      {
        result: 'NOK',
        id: 0,
        offset: offset,
        title: title,
        filename: filename
      }
    end
  result
end

def get_title_and_body(filename)
  content = File.read(filename)
  m = %r{^<html><head><title>(.*?)</title></head><body>(.*)</body></html>$}.match(content)
  title = m[1]
  body = m[2]
  unless title && body
    puts "get_title_and_body() file '#{filename}' has invalid title and/or body => SKIP"
  end
  [title, body]
end

def create_page(c)
  parent = get_parent(c[:offset])
  if parent
    puts "#{parent[:offset]} '#{parent[:name]}' ::"
  else
    puts 'No parent ::'
  end

  puts "#{c[:offset]} #{c[:type]} '#{c[:name]}' #{c[:id]} #{c[:url]}"

  if %w{category folder}.include?(c[:type])
    create_page_item(nil, c[:name], '', c[:offset], parent)
  else
    filename = "#{DATA}/#{c[:id]}.html"
    unless File.exist?(filename)
      puts "create_page() file '#{filename}' does not exist => EXIT"
      exit
    end

    title, body = get_title_and_body(filename)
    create_page_item(filename, title, body, c[:offset], parent)
  end
end

def create_all_pages(categories_tree)
  categories_tree.each do |c|
    create_page(c)
    create_all_pages(c[:folders]) if c[:folders] && c[:folders].length.positive?
    create_all_pages(c[:pages]) if c[:pages] && c[:pages].length.positive?
  end
  write_csv_file('created-pages.csv', @created_pages)
  puts "Done!\n"
end

def create_all_pages_miscellaneous
  offset = @categories_tree.length.to_s
  puts "\ncreate_all_pages_miscellaneous() length='#{@miscellaneous.length}'"
  create_page_item('', 'Miscellaneous', '', offset, nil)
  parent = { offset: offset }
  @miscellaneous.each_with_index do |id, index|
    filename = "#{DATA}/#{id}.html"
    unless File.exist?(filename)
      puts "create_all_pages_miscellaneous() file '#{filename}' does not exist => SKIP"
      next
    end
    title, body = get_title_and_body(filename)
    create_page_item(filename, title, body, "#{offset}-#{index}", parent)
  end
  puts "Done!\n"
end

# image => counter,filename,title,tag,page,value
def upload_image(page_id, image, counter, total)
  c = image['counter']
  id = image['filename'].sub(/\.html$/, '')
  image_basename = File.basename(image['value'])
  confluence_create_attachment(page_id, "#{IMAGES}/#{image_basename}", counter, total)
end

def upload_all_images
  uploaded_images = []
  links = read_csv_file('links.csv')
  fb_to_page_id = {}
  read_csv_file('created-pages.csv').each do |page|
    next unless page['filename'] && page['filename'].length.positive?
    fb_to_page_id[page['filename'].gsub(%r{^#{DATA}\/|\.html}, '')] = page['id']
  end
  images = links.filter { |link| link['tag'] == 'image' }
  total = images.length
  puts "\nUploading #{total} images"
  images.each_with_index do |image, index|
    image_basename = File.basename(image['value'])
    filename = image['filename']
    fb = filename.sub(/\.html/, '')
    page_id = fb_to_page_id[fb]
    if page_id
      result = upload_image(page_id, image, index + 1, total)
      uploaded_images <<
        if result
          {
            result: 'OK',
            reason: '',
            page_id: page_id,
            image_id: result['results'][0]['id'],
            image_basename: image_basename
          }
        else
          {
            result: 'NOK',
            reason: 'FAIL',
            page_id: page_id,
            image_id: '',
            image_basename: image_basename
          }
        end
    else
      puts "upload_all_images() cannot find page_id for image='#{filename}' => SKIP"
      uploaded_images << {
        result: 'NOK',
        reason: 'SKIP',
        page_id: '',
        image_id: '',
        image_basename: image_basename
      }
    end
  end
  write_csv_file('uploaded-images.csv', uploaded_images)
  puts "Done!\n"
end

# Convert all <img src="path/to/{image}" ... /> to
# <ac:image ac:height="250"><ri:attachment ri:filename="{image}" ri:version-at-save="1" /></ac:image>
def convert_all_image_links
  pages = []
  read_csv_file('links.csv').each do |link|
    tag = link['tag']
    filename = link['filename']
    image = link['value']
    next unless tag == 'image'
    page = pages.find { |page| page[:filename] == filename}
    if page
      page[:images] << image
    else
      pages << {
        filename: filename,
        images: [image]
      }
    end
  end
  puts "\nPages with links: #{pages.length}"
  total_images = 0
  pages.each do |page|
    filename = page[:filename]
    images = page[:images].length
    puts "* #{filename} => #{images}"
    page[:images].each do |image|
      puts "  * #{image}"
    end
    total_images += images
  end
  puts "Total images: #{total_images}"
end

@categories_tree = build_categories_tree
show_categories(@categories_tree)
@offset_to_item = build_offset_to_item(@categories_tree, @offset_to_item)
sanity_check
# get_all_links
# download_all_images
# create_all_pages(@categories_tree)
# create_all_pages_miscellaneous
# upload_all_images
convert_all_image_links

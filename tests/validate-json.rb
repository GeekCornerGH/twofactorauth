#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json_schemer'
require 'parallel'
@status = 0
seen_names = []

schema = JSONSchemer.schema(File.read('tests/schema.json'))

def error(file, msg)
  @status = 1
  puts "::error file=#{file}:: #{msg}"
end

# rubocop:disable Metrics/BlockLength
Parallel.each(Dir.glob('entries/*/*.json')) do |file|
  begin
    JSON.parse(File.read(file))
  rescue JSON::ParserError => e
    error(file, "Invalid JSON in #{file}\n#{e.full_message}")
    next
  end

  document = JSON.parse(File.read(file))

  unless schema.valid? document
    schema.validate(document).each do |v|
      puts ''
      puts "::error file=#{file}:: '#{v['type'].capitalize}' error in #{file}"
      puts "- tag: #{v['data_pointer'].split('/')[2]}" if v['data_pointer'].split('/').length >= 3
      puts "  data: #{v['data']}" if v['details'].nil?
      puts "  data: #{v['details']}" unless v['details'].nil?
      puts "  expected: #{v['schema']['pattern']}" if v['type'].eql?('pattern')
      puts "  expected: #{v['schema']['format']}" if v['type'].eql?('format')
      puts "  expected: #{v['schema']['required']}" if v['type'].eql?('required')
      puts "  expected: only one of 'tfa' or 'contact'" if v['type'].eql?('oneOf')
      puts "  expected: 'tfa' to contain '#{v['schema']['contains']['const']}'" if v['type'].eql?('contains')
    end
    @status = 1
    next
  end

  domain = document.values[0]['domain']
  url = document.values[0]['url']
  default_url = "https://#{domain}"
  if !url.nil? && (url.eql?(default_url) || url.eql?("#{default_url}/"))
    error(file, "Defining the url property for #{domain} is not necessary - '#{default_url}' is the default value")
  end

  file_name = file.split('/')[2]
  expected_file_name = "#{document.values[0]['domain']}.json"

  unless file_name.eql? expected_file_name
    error(file,
          "File name should be the same as the domain name. Received: #{file_name}. Expected: #{expected_file_name}")
  end

  folder_name = file.split('/')[1]
  expected_folder_name = document.values[0]['domain'][0]

  unless folder_name.eql? expected_folder_name
    error(file,
          "Entry should be in the subdirectory with the same name as the first letter as the domain.
           Received: entries/#{folder_name}. Expected: entries/#{expected_folder_name}")
  end

  name = document.keys[0]
  if seen_names.include? name
    error(file, "An entry with the name '#{name}' already exists. Duplicate site names are not allowed.
    If this entry is not the same site, please rename '#{name}'.")
  else
    seen_names.push(name)
  end
end
# rubocop:enable Metrics/BlockLength

exit(@status)

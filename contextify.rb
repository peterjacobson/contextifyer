#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'date'

# Get the directory where the script is located
SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))

def load_project_config(config_file)
  puts "Debug: Loading config file: #{config_file}"
  config = {}
  begin
    content = File.read(config_file)
    puts "Debug: Config file content:\n#{content}"
    result = eval(content, binding, config_file)
    puts "Debug: Eval result: #{result.inspect}"
    unless result.is_a?(Hash) && result[:project_path] && result[:exclusions]
      raise "Config file must return a hash with :project_path and :exclusions keys"
    end
    config = result
  rescue => e
    puts "Error loading config file: #{e.message}"
    puts e.backtrace
    exit 1
  end
  config
end

def match_exclusion?(path, exclusions)
  path_components = Pathname.new(path).each_filename.to_a
  exclusions.any? do |pattern|
    if pattern == '.*'
      path_components.any? { |part| part.start_with?('.') }
    else
      path_components.any? { |part| File.fnmatch(pattern, part, File::FNM_DOTMATCH) } ||
      File.fnmatch(pattern, path, File::FNM_DOTMATCH)
    end
  end
end

def within_project_path?(file_path, project_path)
  Pathname.new(file_path).expand_path.to_s.start_with?(project_path.to_s)
end

def format_file_size(size)
  units = ['B', 'KB', 'MB', 'GB', 'TB']
  unit_index = 0
  while size >= 1024 && unit_index < units.length - 1
    size /= 1024.0
    unit_index += 1
  end
  "#{size.round(2)} #{units[unit_index]}"
end

def list_files_to_copy(project_dir, exclusions)
  project_path = Pathname.new(project_dir).expand_path
  files_to_copy = []

  Dir.glob(File.join(project_path, '**', '*'), File::FNM_DOTMATCH) do |file|
    next unless within_project_path?(file, project_path)
    
    relative_path = Pathname.new(file).relative_path_from(project_path)
    
    next if File.directory?(file)
    next if match_exclusion?(relative_path.to_s, exclusions)
    
    size = File.size(file)
    formatted_size = format_file_size(size)
    large_file_marker = size >= 100_000 ? " !!!!!!!!!!!!!!!!!!!!!!" : ""
    
    files_to_copy << [relative_path.to_s, size, formatted_size, large_file_marker]
  end

  files_to_copy.sort_by { |_, size, _, _| size }
end

def bundle_project(project_dir, exclusions, output_file, files_to_copy)
  project_path = Pathname.new(project_dir).expand_path

  # Ensure the directory exists
  FileUtils.mkdir_p(File.dirname(output_file))

  File.open(output_file, 'w:utf-8') do |bundle|
    files_to_copy.each do |file, _, _|
      file_path = project_path.join(file)
      bundle.puts "--- BEGIN FILE: #{file} ---"
      begin
        bundle.puts File.read(file_path, encoding: 'utf-8')
      rescue => e
        bundle.puts "Error reading file: #{e.message}"
      end
      bundle.puts "--- END FILE: #{file} ---"
      bundle.puts "\n"
    end
  end
end

# Check if the script directory is writable
unless File.writable?(SCRIPT_DIR)
  puts "Error: The directory containing this script (#{SCRIPT_DIR}) is not writable."
  puts "Please ensure you have write permissions for this directory."
  exit 1
end

# Main script
if ARGV.empty?
  puts "Usage: ./aibundle.rb <project_name>"
  exit 1
end

project_name = ARGV[0]
config_file = File.join(SCRIPT_DIR, "/project_configs/#{project_name}.rb")

unless File.exist?(config_file)
  puts "Error: Configuration file '#{config_file}' not found."
  exit 1
end

# Load project configuration
config = load_project_config(config_file)

puts "Debug: Loaded config: #{config.inspect}"

# Validate configuration
unless config[:project_path] && config[:exclusions]
  puts "Error: Invalid configuration in #{config_file}. Make sure both project_path and exclusions are defined."
  exit 1
end

# List files to be copied
files_to_copy = list_files_to_copy(config[:project_path], config[:exclusions])

puts "The following files will be copied (sorted by size, largest first):"
files_to_copy.each do |file, _, formatted_size, large_file_marker|
  puts "#{file} (#{formatted_size})#{large_file_marker}"
end

total_files = files_to_copy.size
total_size = files_to_copy.sum { |_, size, _, _| size }

puts "\nTotal files to be copied: #{total_files}"
puts "Total size of files to copy: #{format_file_size(total_size)}"

# Confirm with user
print "\nDo you want to proceed with copying these files? (y/n): "
user_input = $stdin.gets.chomp.downcase

unless user_input == 'y'
  puts "Operation cancelled by user."
  exit 0
end

# Set output file name
date_str = Date.today.strftime("%Y-%m-%d")
output_file = File.join(SCRIPT_DIR, "/bundled_output/#{project_name}-#{date_str}.txt")

# Run the bundler
begin
  bundle_project(config[:project_path], config[:exclusions], output_file, files_to_copy)
  puts "Project bundled successfully. Output file: #{output_file}"
rescue => e
  puts "Error occurred while bundling the project: #{e.message}"
  puts e.backtrace
end
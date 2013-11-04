# Requires
require 'snoo'
require 'yaml'

require_relative 'scanner'

# Load Config
config = YAML::load_file(File.join(__dir__, 'config.yml'))

# Create our reddit client
puts "Logging into reddit..."
reddit = Snoo::Client.new useragent: "Baseball-Stat-Bot"
reddit.log_in config['reddit']['user'], config['reddit']['password']

puts "Scanning comments..."
scanner = BaseOnBot::Scanner.new(reddit, config)
replies = scanner.get_replies()

replies.each do |reply|
  sleep 3
  # puts reply[:reply]
  puts "Replying to comment #{reply[:id]}..."
  reddit.comment reply[:reply], reply[:id]
end

# Logout
reddit.log_out
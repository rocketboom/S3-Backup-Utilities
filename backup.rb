require 'yaml'

def error(str)
  $stderr.puts str
  exit
end

# check if config.yml exists
config = YAML.load_file('config.yml')
error 'Your config.yml is empty.' unless config

# check path to s3sync
S3SYNC = config['s3sync']
error 'You must provide the path to s3sync.rb in config.yml' if S3SYNC.nil?

# check connections in config
connections = config['connections']
error 'You must list your connections in config.yml' if connections.nil?

# process each connection
connections.each do |connection, details|
  # check connection details
  error 'You must set up your connection and job details in config.yml' if connection.nil? || details.nil?

  key = details['AWS_ACCESS_KEY_ID']
  secret = details['AWS_SECRET_ACCESS_KEY']
  cert_dir = details['SSL_CERT_DIR']

  # check connection credentials
  error 'You must set up your connection credentials in config.yml' if key.nil? || secret.nil? || cert_dir.nil?

  # set environment variables for s3sync
  ENV['AWS_ACCESS_KEY_ID'] = key
  ENV['AWS_SECRET_ACCESS_KEY'] = secret
  ENV['SSL_CERT_DIR'] = cert_dir

  puts " Processing #{connection} ".center 80, '='
  puts

  # check jobs
  if details['jobs'].nil?
    puts "No jobs found for #{connection}."
    next
  end

  # process each job
  details['jobs'].each do |job, instructions|
    puts "Executing #{job}:"

    # check job instructions
    if job.nil? || instructions.nil?
      puts "  No instructions found for #{job}.\n\n"
      next
    end

    # use default or specified instructions
    from = instructions['from']
    to = instructions['to']
    type = instructions['type'] || 'files'
    options = instructions['options'] || 'srv'
    options = "-#{options}"
    timestamp = instructions['timestamp'] || false

    to = "#{to}/#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}" if timestamp

    # check for a source and destination
    if instructions['from'].nil? || instructions['to'].nil?
      puts "  Missing source or destination in #{job}.\n\n"
      next
    end

    # call s3sync
    cmd = "#{S3SYNC} #{options} #{from} #{to}"
    puts "  #{cmd}"
    # puts `#{cmd}`

    puts "  Finished on #{Time.now}"
    puts
  end
end

puts "Finished."
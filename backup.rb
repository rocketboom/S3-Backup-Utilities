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
    dbs = instructions['dbs']
    type = instructions['type'] || 'files'
    options = instructions['options'] || 'srv'
    options = "-#{options}"
    timestamp = instructions['timestamp'] || false
    timestamp = true unless dbs.nil?

    to = "#{to}/#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}" if timestamp

    # check for a source and destination (unless db)
    if dbs.nil? && (from.nil? || to.nil?)
      puts "  Missing destination in #{job}.\n\n"
      next
    end

    if dbs.nil? # process files
      cmd = "#{S3SYNC} #{options} #{from} #{to}"
      puts "  #{cmd}"
      puts `#{cmd}`
    else # process db dump
      dbs.each do |db|
        file = "#{db}-#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}.sql.gz"

        # gzip the dump into tmp
        cmd = "mysqldump #{db} | gzip > /tmp/#{file}"
        puts "  #{cmd}"
        puts `#{cmd}`

        # create a new directory for the dump
        tmp_dir = "#{Time.now.strftime '%m-%d-%Y-%H-%M-%S'}"
        cmd = "mkdir /tmp/#{tmp_dir}"
        puts "  #{cmd}"
        puts `#{cmd}`

        # move the dump into the new directory
        cmd = "mv /tmp/#{file} /tmp/#{tmp_dir}/#{file}"
        puts "  #{cmd}"
        puts `#{cmd}`

        # send to S3
        cmd = "#{S3SYNC} #{options} /tmp/#{tmp_dir}/ #{to}"
        puts "  #{cmd}"
        puts `#{cmd}`

        # remove tmp dir
        cmd = "rm -rf /tmp/#{tmp_dir}"
        puts "  #{cmd}"
        `#{cmd}`

        puts
      end
    end

    puts "  Finished on #{Time.now}"
    puts
  end
end

puts "Finished."
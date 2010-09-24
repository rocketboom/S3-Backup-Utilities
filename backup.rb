#
# S3 Backup Utilities
# Developed by Rocketboom R&D (James Wu & Greg Leuch) with support from s3sync.net.
# 
# Released under GNU public license in conjunction with (C) s3sync by s3sync.net.
# --------------------------------------------------------------------------------
#
#
#
#
#



require 'yaml'

def error(str)
  $stderr.puts str
  exit
end

def timestamp; "[#{Time.now.to_s}]"; end

# check if config.yml exists
config = YAML.load_file('config.yml')
error "#{timestamp} Your config.yml is empty." unless config

# check path to s3sync
S3SYNC = config['s3sync']
error "#{timestamp} You must provide the path to s3sync.rb in config.yml" if S3SYNC.nil?

# check connections in config
connections = config['connections']
error "#{timestamp} You must list your connections in config.yml" if connections.nil?

# process each connection
connections.each do |connection, details|
  # check connection details
  error "#{timestamp} You must set up your connection and job details in config.yml" if connection.nil? || details.nil?

  key = details['AWS_ACCESS_KEY_ID']
  secret = details['AWS_SECRET_ACCESS_KEY']
  cert_dir = details['SSL_CERT_DIR']

  # check connection credentials
  error "#{timestamp} You must set up your connection credentials in config.yml" if key.nil? || secret.nil? || cert_dir.nil?

  # set environment variables for s3sync
  ENV['AWS_ACCESS_KEY_ID'] = key
  ENV['AWS_SECRET_ACCESS_KEY'] = secret
  ENV['SSL_CERT_DIR'] = cert_dir

  puts "#{timestamp} Processing #{connection} "
  puts

  # check jobs
  if details['jobs'].nil?
    puts "#{timestamp} No jobs found for #{connection}."
    next
  end

  # process each job
  details['jobs'].each do |job, instructions|
    puts "#{timestamp} Executing #{job}:"

    # check job instructions
    if job.nil? || instructions.nil?
      puts "#{timestamp} No instructions found for #{job}.\n\n"
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
      puts "#{timestamp} Missing destination in #{job}.\n\n"
      next
    end

    if dbs.nil? # process files
      cmd = "#{S3SYNC} #{options} #{from} #{to}"
      puts "#{timestamp} Command: #{cmd}"
      puts `#{cmd}`
    else # process db dump
      dbs.each do |db|
        file = "#{db}-#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}.sql.gz"

        # gzip the dump into tmp
        cmd = "mysqldump #{db} | gzip > /tmp/#{file}"
        puts "#{timestamp} Command: #{cmd}"
        puts `#{cmd}`

        # create a new directory for the dump
        tmp_dir = "#{Time.now.strftime '%m-%d-%Y-%H-%M-%S'}"
        cmd = "mkdir /tmp/#{tmp_dir}"
        puts "#{timestamp} Command: #{cmd}"
        puts `#{cmd}`

        # move the dump into the new directory
        cmd = "mv /tmp/#{file} /tmp/#{tmp_dir}/#{file}"
        puts "#{timestamp} Command: #{cmd}"
        puts `#{cmd}`

        # send to S3
        cmd = "#{S3SYNC} #{options} /tmp/#{tmp_dir}/ #{to}"
        puts "#{timestamp} Command: #{cmd}"
        puts `#{cmd}`

        # remove tmp dir
        cmd = "rm -rf /tmp/#{tmp_dir}"
        puts "#{timestamp} Command: #{cmd}"
        `#{cmd}`

        puts
      end
    end

    puts "#{timestamp} Finished #{job}."
    puts
  end
end

puts "#{timestamp} Finished backup utilities."
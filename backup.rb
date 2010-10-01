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


# -------------

require 'yaml'


# -------------

# Output as error & exit.
def error(str)
  $stderr.puts str
  exit
end

# Make pretty timestamp
def timestamp; "[#{Time.now.to_s}]"; end


# -------------

puts "#{timestamp} Beginning backup jobs."


# Check if config.yml exists
config = YAML.load_file('config.yml')
error "Your config.yml is empty." unless config

# Check path to s3sync
S3SYNC = config['s3sync']
error "You must provide the path to s3sync.rb in config.yml" if S3SYNC.nil?

# Check connections in config
connections = config['connections']
error "You must list your connections in config.yml" if connections.nil?


# Process each connection
connections.each do |connection, details|
  # check connection details
  if connection.nil? || details.nil?
    puts "#{timestamp} ERROR: You must set up your connection and job details in config.yml for #{connection}"
    next
  end

  key = details['AWS_ACCESS_KEY_ID']
  secret = details['AWS_SECRET_ACCESS_KEY']
  cert_dir = details['SSL_CERT_DIR']

  # check connection credentials
  if key.nil? || secret.nil? || cert_dir.nil?
    puts "#{timestamp} ERROR: You must set up your connection credentials in config.yml for #{connection}"
    next
  end

  # set environment variables for s3sync
  ENV['AWS_ACCESS_KEY_ID'] = key
  ENV['AWS_SECRET_ACCESS_KEY'] = secret
  ENV['SSL_CERT_DIR'] = cert_dir

  puts "#{timestamp} Processing #{connection}..."

  # check jobs
  if details['jobs'].nil?
    puts "#{timestamp} No jobs found for #{connection}."
    next
  end

  # process each job
  details['jobs'].each do |job, instructions|
    puts "#{timestamp} Executing #{connection}:#{job}..."

    # check job instructions
    if job.nil? || instructions.nil?
      puts "#{timestamp} No instructions found for #{connection}:#{job}.\n\n"
      next
    end

    job_type = instructions['type'] || 'files'
    job_dbs = instructions['dbs'] || false
    job_to = instructions['to']
    job_options = "-#{instructions['options'] || 'srv'}"

    # Config for database backups
    if job_dbs
      job_timestamp = true

    # Config for file and other jobs
    else
      job_timestamp = instructions['timestamp'] || false
      job_from = instructions['from']
    end


    # Add timestamp folder if required.
    job_to = "#{to}/#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}" if job_timestamp


    # Check for a source and destination (unless db)
    if dbs.nil? && (from.nil? || to.nil?)
      puts "#{timestamp} Missing destination in #{connection}:#{job}.\n\n"
      next
    end


    # Begin backup for databases
    unless dbs.nil?
      dbs.each do |db|
        puts "#{timestamp} Begin db backup of #{connection}:#{job}:#{db}..."
        file = "#{db}-#{Time.now.strftime '%m-%d-%Y-%H:%M:%S'}.sql.gz"

        # gzip the dump into tmp
        cmd = "mysqldump #{db} | gzip > ./tmp/#{file}"
        puts "#{timestamp} Command: #{cmd}" if DEBUG
        `#{cmd}`

        # create a new directory for the dump
        tmp_dir = "#{Time.now.strftime '%m-%d-%Y-%H-%M-%S'}"
        cmd = "mkdir -p ./tmp/#{tmp_dir}"
        puts "#{timestamp} Command: #{cmd}" if DEBUG
        `#{cmd}`

        # move the dump into the new directory
        cmd = "mv ./tmp/#{file} ./tmp/#{tmp_dir}/#{file}"
        puts "#{timestamp} Command: #{cmd}" if DEBUG
        `#{cmd}`

        # send to S3
        cmd = "#{S3SYNC} #{options} ./tmp/#{tmp_dir}/ #{to}"
        puts "#{timestamp} Command: #{cmd}" if DEBUG
        `#{cmd}`

        # remove tmp dir
        cmd = "rm -rf ./tmp/#{tmp_dir}"
        puts "#{timestamp} Command: #{cmd}" if DEBUG
        `#{cmd}`

        puts "#{timestamp} Completed db backup of #{db}.\n\n"
      end

    # Begin backup for files and other jobs
    else
      puts "#{timestamp} Trasnmitting files for #{connection}:#{job}..."
      cmd = "#{S3SYNC} #{options} #{from} #{to}"
      puts "#{timestamp} Command: #{cmd}" if DEBUG
      `#{cmd}`
    end

    puts "#{timestamp} Completed #{connection}:#{job}."
  end
end

puts "#{timestamp} Completed backup jobs."
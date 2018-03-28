#!/usr/bin/env ruby
#
# Listen for AWS CloudWatch Events EC2 termination events delivered via SQS
# and remove the node from Chef and Sensu and send a notification
# to Hipchat or Slack
#
# Copyright (c) 2015-2017 Eric Heydrick
# Licensed under The MIT License
#

# ensure gems are present
begin
  require 'json'
  require 'yaml'
  require 'aws-sdk-core'
  require 'chef-api'
  require 'hipchat'
  require 'rest-client'
  require 'trollop'
  require 'slack/poster'
  require 'logger'
rescue LoadError => e
  raise "Missing gems: #{e}"
end

# require our class
require_relative '../lib/aws-cleaner.rb'

def config(file)
  YAML.safe_load(File.read(File.expand_path(file)), [Symbol])
rescue StandardError => e
  raise "Failed to open config file: #{e}"
end

def logger(config)
  file = config[:log][:file] unless config[:log].nil?

  if file
    begin
      # Check if specified file can be written
      awslog = File.open(File.expand_path(file), File::CREAT | File::WRONLY | File::APPEND)
    rescue StandardError => e
      $stderr.puts "aws-cleaner: ERROR - Failed to open log file #{file} beause of #{e}. STDOUT will be used instead."
    end
  else
    $stdout.puts 'aws-cleaner: WARN - Log file is not specified. STDOUT will be used instead.'
  end

  # Use STDOUT if it is not possible to write to log file
  awslog = STDOUT if awslog.nil?

  # Make sure log is flushed out immediately instead of being buffered
  awslog.sync = true

  logger = Logger.new(awslog)

  # Configure logger to escape all data
  formatter = Logger::Formatter.new
  logger.formatter = proc { |severity, datetime, progname, msg|
    formatter.call(severity, datetime, progname, msg.dump)
  }

  logger
end

def webhook(id, instance_id)
  if @config[:webhooks]
    @config[:webhooks].each do |hook, hook_config|
      if AwsCleaner::Webhooks.fire_webhook(hook_config, @config, instance_id)
        @logger.info("Successfully ran webhook #{hook}")
      else
        @logger.info("Failed to run webhook #{hook}")
      end
    end
    AwsCleaner.new.delete_message(id, @config)
  end
end

def chef(id, instance_id, chef_node)
  if chef_node
    if AwsCleaner::Chef.remove_from_chef(chef_node, @chef_client, @config)
      @logger.info("Removed #{chef_node} from Chef")
      AwsCleaner.new.delete_message(id, @config)
    end
  else
    @logger.info("Instance #{instance_id} does not exist in Chef, deleting message")
    AwsCleaner.new.delete_message(id, @config)
  end
end

def sensu(id, instance_id, chef_node)
  return unless @config[:sensu][:enable]
  if AwsCleaner::Sensu.in_sensu?(chef_node, @config)
    if AwsCleaner::Sensu.remove_from_sensu(chef_node, @config)
      @logger.info("Removed #{chef_node} from Sensu")
    else
      @logger.info("Instance #{instance_id} does not exist in Sensu, deleting message")
    end
    AwsCleaner.new.delete_message(id, @config)
  end
end

def closelog(message)
  @logger.debug(message) unless message.nil?
  @logger.close
end

# get options
opts = Trollop.options do
  opt :config, 'Path to config file', type: :string, default: 'config.yml'
end

@config = config(opts[:config])
@logger = logger(@config)
@sqs_client = AwsCleaner::SQS.client(@config)
@chef_client = AwsCleaner::Chef.client(@config)

# to provide backwards compatibility as this key did not exist previously
@config[:sensu][:enable] = if @config[:sensu][:enable].nil?
                             true
                           else
                             @config[:sensu][:enable]
                           end

# main loop
loop do
  begin
    # get messages from SQS
    messages = @sqs_client.receive_message(
      queue_url: @config[:sqs][:queue],
      max_number_of_messages: 10,
      visibility_timeout: 3
    ).messages

    @logger.info("Got #{messages.size} messages") unless messages.empty?

    messages.each_with_index do |message, index|
      @logger.info("Looking at message number #{index}")
      body = AwsCleaner.new.parse(message.body)
      id = message.receipt_handle

      unless body
        AwsCleaner.new.delete_message(id, @config)
        next
      end

      instance_id = AwsCleaner.new.process_message(body)

      if instance_id
        chef_node = AwsCleaner::Chef.get_chef_node_name(instance_id, @config)
        webhook(id, instance_id)
        chef(id, instance_id, chef_node)
        sensu(id, instance_id, chef_node)
      else
        @logger.info('Message not relevant, deleting')
        AwsCleaner.new.delete_message(id, @config)
      end
    end

    sleep(5)
  rescue Interrupt
    closelog('Received Interrupt signal. Quit aws-cleaner')
    exit
  rescue StandardError => e
    @logger.error("Encountered #{e}: #{e.message}")
  end
end

#!/usr/bin/env ruby
#
# Listen for AWS CloudWatch Events EC2 termination events delivered via SQS
# and remove the node from Chef and Sensu and send a notification
# to Hipchat or Slack
#
# Copyright (c) 2015, 2016 Eric Heydrick
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
rescue LoadError => e
  raise "Missing gems: #{e}"
end

# require our class
require_relative '../lib/aws_cleaner/aws_cleaner.rb'

def config(file)
  YAML.load(File.read(file))
rescue StandardError => e
  raise "Failed to open config file: #{e}"
end

# get options
opts = Trollop.options do
  opt :config, 'Path to config file', type: :string, default: 'config.yml'
end

@config = config(opts[:config])

# @sqs = Aws::SQS::Client.new(@config[:aws])
@sqs_client = AwsCleaner::SQS.client(@config)

@chef_client = AwsCleaner::Chef.client(@config)

# main loop
loop do
  # get messages from SQS
  messages = @sqs_client.receive_message(
    queue_url: @config[:sqs][:queue],
    max_number_of_messages: 10,
    visibility_timeout: 3
  ).messages

  puts "Got #{messages.size} messages"

  messages.each_with_index do |message, index|
    puts "Looking at message number #{index}"
    body = AwsCleaner.new.parse(message.body)
    id = message.receipt_handle

    unless body
      AwsCleaner.new.delete_message(id, @config)
      next
    end

    @instance_id = AwsCleaner.new.process_message(body)

    if @instance_id
      if @config[:webhooks]
        @config[:webhooks].each do |hook, hook_config|
          if AwsCleaner::Webhooks::fire_webhook(hook_config, @config, @instance_id)
            puts "Successfully ran webhook #{hook}"
          else
            puts "Failed to run webhook #{hook}"
          end
        end
        AwsCleaner.new.delete_message(id, @config)
      end

      chef_node = AwsCleaner::Chef.get_chef_node_name(@instance_id, @config)

      if chef_node
        if AwsCleaner::Chef.remove_from_chef(chef_node, @chef_client, @config)
          puts "Removed #{chef_node} from Chef"
          AwsCleaner.new.delete_message(id, @config)
        end
      else
        puts "Instance #{@instance_id} does not exist in Chef, deleting message"
        AwsCleaner.new.delete_message(id, @config)
      end

      if AwsCleaner::Sensu.in_sensu?(chef_node, @config)
        if AwsCleaner::Sensu.remove_from_sensu(chef_node, @config)
          puts "Removed #{chef_node} from Sensu"
        else
          puts "Instance #{@instance_id} does not exist in Sensu, deleting message"
        end
        AwsCleaner.new.delete_message(id, @config)
      end

    else
      puts 'Message not relevant, deleting'
      AwsCleaner.new.delete_message(id, @config)
    end
  end

  sleep(5)
end

#!/usr/bin/env ruby
#
# Listen for AWS Config EC2 termination events delivered via SQS
# and remove the node from Chef and Sensu and send a notification
# to Hipchat
#
# Copyright (c) 2015 Eric Heydrick
# Licensed under The MIT License
#

begin
  require 'json'
  require 'yaml'
  require 'aws-sdk-core'
  require 'chef-api'
  require 'hipchat'
  require 'rest-client'
  require 'trollop'
rescue LoadError => e
  raise "Missing gems: #{e}"
end

def config(file)
  YAML.load(File.read(file))
  rescue StandardError => e
    raise "Failed to open config file: #{e}"
end

# get options
opts = Trollop::options do
  opt :config, 'Path to config file', :type => :string, :default => 'config.yml'
end

@config = config(opts[:config])

@sqs = Aws::SQS::Client.new(@config[:aws])

@chef = ChefAPI::Connection.new(
  endpoint: @config[:chef][:url],
  client: @config[:chef][:client],
  key: @config[:chef][:key]
)

# delete the message from SQS
def delete_message(id)
  delete = @sqs.delete_message(
    queue_url: @config[:sqs][:queue],
    receipt_handle: id
   )
  delete ? true : false
end

# return the body of the SQS message in JSON
def parse(body)
  JSON.parse(body)
  rescue JSON::ParserError
    return false
end

# return the instance_id of the terminated instance
def process_message(message_body)
  return false if message_body['configurationItem'].nil? &&
                  message_body['configurationItemDiff'].nil?

  if message_body['configurationItem']['resourceType'] == 'AWS::EC2::Instance' &&
     message_body['configurationItem']['configurationItemStatus'] == 'ResourceDeleted' &&
     message_body['configurationItemDiff']['changeType'] == 'DELETE'
    instance_id = message_body['configurationItem']['resourceId']
  end

  instance_id ? instance_id : false
end

# call the Chef API to get the node name of the instance
def get_chef_node_name(instance_id)
  results = @chef.search.query(:node, "ec2_instance_id:#{instance_id}")
  if results.rows.size > 0
    return results.rows.first['name']
  else
    return false
  end
end

# check if the node exists in Sensu
def in_sensu?(node_name)
  begin
    RestClient.get("#{@config[:sensu][:url]}/clients/#{node_name}")
  rescue RestClient::ResourceNotFound
    return false
  rescue => e
    puts "Sensu request failed: #{e}"
    return false
  else
    return true
  end
end

# call the Sensu API to remove the node
def remove_from_sensu(node_name)
  response = RestClient.delete("#{@config[:sensu][:url]}/clients/#{node_name}")
  case response.code
  when 202
    notify_hipchat('Removed ' + node_name + ' from Sensu') if @config[:hipchat][:enable]
    return true
  else
    notify_hipchat('Failed to remove ' + node_name + ' from Sensu') if @config[:hipchat][:enable]
    return false
  end
end

# call the Chef API to remove the node
def remove_from_chef(node_name)
  begin
    client = @chef.clients.fetch(node_name)
    client.destroy
    node = @chef.nodes.fetch(node_name)
    node.destroy
  rescue => e
    puts "Failed to remove chef node: #{e}"
  else
    notify_hipchat('Removed ' + node_name + ' from Chef') if @config[:hipchat][:enable]
  end
end

def notify_hipchat(msg)
  hipchat = HipChat::Client.new(
    @config[:hipchat][:api_token],
    api_version: 'v2'
  )
  room = @config[:hipchat][:room]
  hipchat[room].send('AWS Cleaner', msg)
end

# main loop
loop do
  # get messages from SQS
  messages = @sqs.receive_message(
    queue_url: @config[:sqs][:queue],
    max_number_of_messages: 10,
    visibility_timeout: 3
  ).messages

  puts "Got #{messages.size} messages"

  messages.each_with_index do |message, index|
    puts "Looking at message number #{index}"
    body = parse(message.body)
    id = message.receipt_handle

    unless body
      delete_message(id)
      next
    end

    instance_id = process_message(body)

    if instance_id
      chef_node = get_chef_node_name(instance_id)

      if chef_node
        if remove_from_chef(chef_node)
          puts "Removed #{chef_node} from Chef"
          delete_message(id)
        end
      else
        puts "Instance #{instance_id} does not exist in Chef, deleting message"
        delete_message(id)
      end

      if in_sensu?(chef_node)
        if remove_from_sensu(chef_node)
          puts "Removed #{chef_node} from Sensu"
          delete_message(id)
        else
          puts "Instance #{instance_id} does not exist in Sensu, deleting message"
          delete_message(id)
        end
      end
    else
      puts 'Message not relevant, deleting'
      delete_message(id)
    end
  end

  sleep(5)
end

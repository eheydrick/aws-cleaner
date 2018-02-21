# main aws_cleaner lib
class AwsCleaner
  # SQS related stuff
  module SQS
    # sqs connection
    def self.client(config)
      Aws::SQS::Client.new(config[:aws])
    end
  end

  # delete the message from SQS
  def delete_message(id, config)
    delete = AwsCleaner::SQS.client(config).delete_message(
      queue_url: config[:sqs][:queue],
      receipt_handle: id
    )
    delete ? true : false
  end

  module Chef
    # chef connection
    def self.client(config)
      ChefAPI::Connection.new(
        endpoint: config[:chef][:url],
        client: config[:chef][:client],
        key: config[:chef][:key]
      )
    end

    # call the Chef API to get the node name of the instance
    def self.get_chef_node_name(instance_id, config)
      chef = client(config)
      results = chef.search.query(:node, "ec2_instance_id:#{instance_id} OR chef_provisioning_reference_server_id:#{instance_id}")
      return false if results.rows.empty?
      results.rows.first['name']
    end

    # call the Chef API to get the FQDN of the instance
    def self.get_chef_fqdn(instance_id, config)
      chef = client(config)
      results = chef.search.query(:node, "ec2_instance_id:#{instance_id} OR chef_provisioning_reference_server_id:#{instance_id}")
      return false if results.rows.empty?
      results.rows.first['automatic']['fqdn']
    end

    # call the Chef API to remove the node
    def self.remove_from_chef(node_name, chef, config)
      client = chef.clients.fetch(node_name)
      client.destroy
      node = chef.nodes.fetch(node_name)
      node.destroy
    rescue StandardError => e
      puts "Failed to remove chef node: #{e}"
    else
      # puts "Removed #{node_name} from chef"
      AwsCleaner::Notify.notify_chat('Removed ' + node_name + ' from Chef', config)
    end
  end

  module Sensu
    # check if the node exists in Sensu
    def self.in_sensu?(node_name, config)
      RestClient::Request.execute(
        url: "#{config[:sensu][:url]}/clients/#{node_name}",
        method: :get,
        timeout: 5,
        open_timeout: 5
      )
    rescue RestClient::ResourceNotFound
      return false
    rescue StandardError => e
      puts "Sensu request failed: #{e}"
      return false
    else
      return true
    end

    # call the Sensu API to remove the node
    def self.remove_from_sensu(node_name, config)
      response = RestClient::Request.execute(
        url: "#{config[:sensu][:url]}/clients/#{node_name}",
        method: :delete,
        timeout: 5,
        open_timeout: 5
      )
      case response.code
      when 202
        AwsCleaner::Notify.notify_chat('Removed ' + node_name + ' from Sensu', config)
        return true
      else
        AwsCleaner::Notify.notify_chat('Failed to remove ' + node_name + ' from Sensu', config)
        return false
      end
    end
  end

  # return the body of the SQS message in JSON
  def parse(body)
    JSON.parse(body)
  rescue JSON::ParserError
    return false
  end

  # return the instance_id of the terminated instance
  def process_message(message_body)
    return false if message_body['detail']['instance-id'].nil? &&
                    message_body['detail']['state'] != 'terminated'

    instance_id = message_body['detail']['instance-id']
    instance_id
  end

  module Notify
    # notify hipchat
    def self.notify_hipchat(msg, config)
      hipchat = HipChat::Client.new(
        config[:hipchat][:api_token],
        api_version: 'v2'
      )
      room = config[:hipchat][:room]
      hipchat[room].send('AWS Cleaner', msg)
    end

    # notify slack
    def self.notify_slack(msg, config)
      slack = Slack::Poster.new(config[:slack][:webhook_url])
      slack.channel = config[:slack][:channel]
      slack.username = config[:slack][:username] ||= 'aws-cleaner'
      slack.icon_emoji = config[:slack][:icon_emoji] ||= nil
      slack.send_message(msg)
    end

    # generic chat notification method
    def self.notify_chat(msg, config)
      if config[:hipchat][:enable]
        notify_hipchat(msg, config)
      elsif config[:slack][:enable]
        notify_slack(msg, config)
      end
    end
  end

  module Webhooks
    # generate the URL for the webhook
    def self.generate_template(item, template_variable_method, template_variable, config, instance_id)
      if template_variable_method == 'get_chef_fqdn'
        replacement = AwsCleaner::Chef.get_chef_fqdn(instance_id, config)
      elsif template_variable_method == 'get_chef_node_name'
        replacement = AwsCleaner::Chef.get_chef_node_name(instance_id, config)
      else
        raise 'Unknown templating method'
      end
      item.gsub!(/{#{template_variable}}/, replacement)
    rescue StandardError => e
      puts "Error generating template: #{e.message}"
      return false
    else
      item
    end

    # call an HTTP endpoint
    def self.fire_webhook(hook_config, config, instance_id)
      # generate templated URL
      if hook_config[:template_variables] && hook_config[:url] =~ /\{\S+\}/
        url = AwsCleaner::Webhooks.generate_template(
          hook_config[:url],
          hook_config[:template_variables][:method],
          hook_config[:template_variables][:variable],
          config,
          instance_id
        )
        return false unless url
      else
        url = hook_config[:url]
      end

      hook = { method: hook_config[:method].to_sym, url: url }
      r = RestClient::Request.execute(hook)
      if r.code != 200
        return false
      else
        # notify chat when webhook is successful
        if hook_config[:chat][:enable]
          msg = AwsCleaner::Webhooks.generate_template(
            hook_config[:chat][:message],
            hook_config[:chat][:method],
            hook_config[:chat][:variable],
            config,
            instance_id
          )
          AwsCleaner::Notify.notify_chat(msg, config)
        end
        return true
      end
    end
  end
end

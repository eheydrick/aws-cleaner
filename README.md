## AWS Cleaner

[![Gem Version](https://badge.fury.io/rb/aws-cleaner.svg)](http://badge.fury.io/rb/aws-cleaner)

AWS Cleaner listens for EC2 termination events produced by AWS Config
and removes the instances from Chef and Sensu monitoring. Optionally
sends messages to Hipchat when actions occur.

### Prerequisites

You will need [AWS Config](http://aws.amazon.com/config/) enabled on
your AWS account and AWS Config needs to be [configured to send
messages to
SQS](http://docs.aws.amazon.com/config/latest/developerguide/monitor-resource-changes.html).

### Installation

1. `gem install aws-cleaner`

### Usage

```
Options:
  -c, --config=<s>    Path to config file (default: config.yml)
  -h, --help          Show this message
```

Copy the example config file ``config.yml.sample`` to ``config.yml``
and fill in the configuration details. You will need AWS Credentials
and are strongly encouraged to use an IAM user with access limited to
the AWS Config SQS queue.

The app takes one arg '-c' that points at the config file. If -c is
omitted it will look for the config file in the current directory.

The app is started by running aws_config.rb and it will run until
terminated. A production install would start it with upstart or
similar.

### Webhooks

AWS Cleaner can optionally make an HTTP request to a specified endpoint. You can
also template the URL that is called. Templating is currently limited to a single
variable and the value can be either the Chef node name or the FQDN of the instance.

To enable webhooks, add a `:webhooks:` section to the config:

```
:webhooks:
  my-webhook:
    :url: 'http://my.webhook.com/blah/{fqdn}'
    :method: GET
    :template_variables:
      :variable: 'fqdn'
      :method: 'get_chef_fqdn' (or 'get_chef_node_name')
      :argument: '@instance_id'
```


### Limitations

Currently only supports a single AWS region.


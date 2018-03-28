## AWS Cleaner

[![Build Status](https://travis-ci.org/eheydrick/aws-cleaner.svg?branch=master)](https://travis-ci.org/eheydrick/aws-cleaner)
[![Gem Version](https://badge.fury.io/rb/aws-cleaner.svg)](http://badge.fury.io/rb/aws-cleaner)
[![Dependency Status](https://gemnasium.com/badges/github.com/eheydrick/aws-cleaner.svg)](https://gemnasium.com/github.com/eheydrick/aws-cleaner)

AWS Cleaner listens for EC2 termination events produced by AWS [CloudWatch Events](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchEvents.html)
and removes the instances from Chef. It can optionally remove the node from Sensu Monitoring (defaults true), fire off webhooks, and send notifications via Hipchat & Slack when actions occur.

![aws-cleaner](https://raw.github.com/eheydrick/aws-cleaner/master/aws-cleaner.png)

### Prerequisites

You will need to create a CloudWatch Events rule that's configured to send termination event messages to SQS.

1. Create an SQS Queue for cloudwatch-events
1. Goto CloudWatch Events in the AWS Console
1. Click *Create rule*
1. Select event source of *EC2 instance state change notification*
1. Select specific state of *Terminated*
1. Add a target of *SQS Queue* and set queue to the cloudwatch-events queue created in step one
1. Give the rule a name/description and click *Create rule*

You will also need to create a user with the required permissions. I recommend creating a 'aws-cleaner' user in chef and add it to its own group. The minimum permissions we found that works is read and delete nodes/clients.

Steps:

1. on chef server: `chef-server-ctl user-create aws-cleaner AWS Cleaner`
1. on chef server: `address@domain.tld "$SOMEREALLYLONGRANDOMPASSWORD" -f aws-cleaner.pem`
1. on chef server: `chef-server-ctl org-user-add $MYORG aws-cleaner`
1. on workstation: `gem install knife-acl`
1. on workstation: `knife group create aws-cleaner`
1. on workstation: `knife group add user aws-cleaner aws-cleaner`
1. on workstation: `knife acl bulk add group aws-cleaner clients '.*' read,delete -y`
1. on workstation: `knife acl bulk add group aws-cleaner nodes '.*' read,delete -y`

An astute reader might notice that this wont work for new nodes that come up as they have not had their ACL updated. I recommend that you add the who bulk acl knife commands (modified for just self as opposed to bulk) as part of your normal bootstrap process before deleting your validation key.

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
the AWS CloudWatch Events SQS queue.You will need to specify the region
in the config even if you are using IAM Credentials.

The app takes one arg '-c' that points at the config file. If -c is
omitted it will look for the config file in the current directory.

The app is started by running aws_config.rb and it will run until
terminated. A production install would start it with upstart or
similar.

### Logging

By default aws-cleaner will log to STDOUT. If you wish to log to a specific file
add a `log` section to the config. See [`config.yml.sample`](config.yml.sample) for an example.

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
```

Chat notifications can be sent when the webhook successfully executes. See
config.yml.sample for an example of the config.

### Sensu

By default aws-cleaner assumes that removing from sensu is desired as this was one of its core intentions. To allow people to leverage this without sensu you can disable it via config:
```
:sensu:
  :enable: false
```

When wanting to use sensu you will want the following config:
```
:sensu:
  :url: 'http://sensu.example.com:4567'
  :enable: true
```

While we currently assume sensu removal being desired is considered the default it may not always be so you should set `enable` to true to avoid a breaking change later.

### Limitations

- Currently only supports a single AWS region.
- Only support chef and sensu with non self signed certificates. Look at Aws Certificate Manager or Let's Encrypt for free SSL certificates.

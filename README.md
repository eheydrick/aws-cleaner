## AWS Cleaner

AWS Cleaner listens for EC2 termination events produced by AWS Config
and removes the instances from Chef and Sensu monitoring. Optionally
sends messages to Hipchat when actions occur.

### Prerequisites

You will need [AWS Config](http://aws.amazon.com/config/) enabled on
your AWS account and AWS Config needs to be [configured to send
messages to
SQS](http://docs.aws.amazon.com/config/latest/developerguide/monitor-resource-changes.html).

### Installation

1. Place the script in a directory. /opt/aws-cleaner, for example
2. ``bundle install --deployment``

### Usage

Copy the example config file ``config.yml.sample`` to ``config.yml``
and fill in the configuration details. You will need AWS Credentials
and are strongly encouraged to use an IAM user with access limited to
the AWS Config SQS queue.

Currently the script does not daemonize but you can run it in a loop:

  ``while true; do ./aws_cleaner.rb; sleep 5; done``

### Limitations

Currently only supports a single AWS region.


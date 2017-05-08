# Changelog

### Unreleased
- renaming gem files to be more easily consumed, previously had to `gem intall aws-cleaner` and then within any code use `require 'aws_cleaner/aws_cleaner.rb'` which just seems silly and should now just be able to `require aws-cleaner`.

### 2.1.0 - 2017-03-28
- Refactor logic into a library (Thanks [@majormoses](https://github.com/majormoses))
- Remove the `argument` parameter from the webhook config. We now always use the instance ID when templating webhooks.

### 2.0.1 - 2016-06-30
- Actually add `slack-poster` dependency

### 2.0.0 - 2016-06-30
- Add support for sending notifications to Slack. Note: the config settings for chat notifications has changed to add support for multiple chat providers.

### 1.0.0 - 2016-04-26
- AWS Cleaner now uses [CloudWatch Events](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchEvents.html) instead of
AWS Config to receive EC2 instance termination events. CloudWatch Events delivers events in seconds while AWS Config can take several minutes.

### 0.3.1 - 2016-04-21
- Add better error handling

### 0.3.0 - 2016-01-06
- Add hipchat notifications when webhooks fire

### 0.2.1 - 2015-12-22
- Fix options

### 0.2.0 - 2015-12-22
- Add webhooks

### 0.1.3 - 2015-07-30
- Look for chef-provisioning attributes when searching for chef nodes

### 0.1.2 - 2015-07-30
- Improve exception handling
- Fix typos
- Notify hipchat only when enabled

### 0.1.1 - 2015-07-29
- Initial release

# Changelog

### Unreleased

### 2.1.0 - 2017-03-28
- refactor logic into a library (Thanks [@majormoses](https://github.com/majormoses))
- remove the `argument` parameter from the config. we now always use the instance ID when templating webhooks

### 2.0.1 - 2016-06-30
- actually add `slack-poster` dependency

### 2.0.0 - 2016-06-30
- add support for sending notifications to Slack. Note: the config settings for chat notifications has changed to add support for multiple chat providers.

### 1.0.0 - 2016-04-26
- AWS Cleaner now uses [CloudWatch Events](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchEvents.html) instead of
AWS Config to receive EC2 instance termination events. CloudWatch Events delivers events in seconds while AWS Config can take several minutes.

### 0.3.1 - 2016-04-21
- add better error handling

### 0.3.0 - 2016-01-06
- add hipchat notifications when webhooks fire

### 0.2.1 - 2015-12-22
- fix options

### 0.2.0 - 2015-12-22
- add webhooks

### 0.1.3 - 2015-07-30
- look for chef-provisioning attributes when searching for chef nodes

### 0.1.2 - 2015-07-30
- improve exception handling
- fix typos
- notify hipchat only when enabled

### 0.1.1 - 2015-07-29
- initial release

# Changelog

### Unreleased

### 2.0.1
- actually add `slack-poster` dependency

### 2.0.0
- add support for sending notifications to Slack. Note: the config settings for chat notifications has changed to add support for multiple chat providers.

### 1.0.0
- AWS Cleaner now uses [CloudWatch Events](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchEvents.html) instead of
AWS Config to receive EC2 instance termination events. CloudWatch Events delivers events in seconds while AWS Config can take several minutes.

### 0.3.1
- add better error handling

### 0.3.0
- add hipchat notifications when webhooks fire

### 0.2.1
- fix options

### 0.2.0
- add webhooks

### 0.1.3
- look for chef-provisioning attributes when searching for chef nodes

### 0.1.2
- improve exception handling
- fix typos
- notify hipchat only when enabled

### 0.1.1
- initial release

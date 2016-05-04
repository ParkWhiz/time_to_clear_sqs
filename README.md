# time_to_clear_sqs
Publishes CloudWatch metrics for time to clear/rate of clearing an sqs queue

## Motivation

Say we have some process that rapidly fills up an SQS queue, and then another
process that gradually processes messages. We might want to know 

1. How long it takes the queue to clear (TimeToClear)
2. How quickly the queue is being emptied (MessageClearRate)
3. How quickly the queue is being filled (MessageAddRate)

time_to_clear_sqs derives these metrics from CloudWatch and then publishes
them.

## Setup

1. Make sure you have ruby and bundler installed
2. Change directory to the repo
3. Run: `bundle install` 
4. `cp config.ini.sample config.ini`
5. Edit config.ini to suit your needs
6. Run `ruby time_to_clear.rb`


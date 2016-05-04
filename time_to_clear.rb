#!/usr/bin/env ruby

require "aws-sdk"
require "inifile"

class CloudWatchClient
  def initialize(region, queue_name, namespace)
    @queue_name = queue_name
    @namespace = namespace
    @cw = Aws::CloudWatch::Client.new(region: region)
  end

  def get_data
    now = Time.now.utc
    five_minutes_ago = now - 300
    response = @cw.get_metric_statistics(
      namespace: "AWS/SQS", 
      metric_name: "ApproximateNumberOfMessagesVisible", 
      start_time: five_minutes_ago, 
      end_time: now, period: 300, statistics: ["Average"],
      unit: "Count", dimensions: [{name: "QueueName", value: @queue_name}])
    if response.successful? && response.datapoints.count > 0
      point = response.datapoints[-1]
      puts "Got: #{point.average} @ #{point.timestamp}"
      return point
    end
  end

  def put_data(timestamp, metric_name, value, unit)
    puts "Writing to #{metric_name}: #{value} #{unit} @ #{timestamp}"
    @cw.put_metric_data(
      namespace: "#{@namespace}/SQS", 
      metric_data: [ 
        { 
          metric_name: metric_name,
          dimensions: [
            {
              name: "QueueName",
              value: @queue_name
            }
          ],
          timestamp: timestamp,
          value: value,
          unit: unit
        }
      ])
  end
end

# http://stackoverflow.com/questions/2206714/can-a-ruby-script-tell-what-directory-it-s-in
script_dir = File.expand_path(File.dirname(__FILE__))
ini_file = File.join(script_dir, "time_to_clear.ini")
settings = IniFile.load(ini_file)

queue_name = settings["general"]["queue"]
region = settings["general"]["region"]
namespace = settings["general"]["namespace"]

client = CloudWatchClient.new(region, queue_name, namespace)

current_max = 0
peak_time = nil
prev_timestamp = nil
prev_value = nil
loop do
  puts "[Entry: #{Time.now.utc}]"
  point = client.get_data
  if point
    timestamp = point.timestamp
    value = point.average
    if value == 0
      # we're at bottom
      if current_max > 0
        # we weren't at a bottom before. Send a report
        current_max = 0
        time_to_clear = timestamp - peak_time
        client.put_data(timestamp, "TimeToClear", time_to_clear, "Seconds")
      end
    elsif value > current_max
      # we're climbing
      current_max = value
      peak_time = timestamp
    end
    if prev_timestamp && prev_timestamp < timestamp
      # If we have a previous point, we calculate velocity
      rate = (value - prev_value).to_f / (timestamp - prev_timestamp)
      if rate > 0
        client.put_data(timestamp, "MessageAddRate", rate, "Count/Second")
      elsif rate < 0
        client.put_data(timestamp, "MessageClearRate", -rate, "Count/Second")
      end
    end
    prev_timestamp = timestamp
    prev_value = value
  end
  puts "current_max: #{current_max}, peak_time: #{peak_time}"
  sleep 300
end

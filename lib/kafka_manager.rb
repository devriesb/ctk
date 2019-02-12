require "kafka"

class KafkaManager
  def initialize
    # Returns:
    # ["hostname1:9092", "hostname2:9092"]
    @broker_hostnames = Box.all
                           .map(&:hostnames)
                           .map{ |hostname| "#{hostname}:9092" }
  end

  def connect
    Kafka.new(@broker_hostnames, client_id: "my-application")
  end
end
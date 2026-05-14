# Mikhael — Personal AI Assistant
# Copyright (C) 2026 Nicolás S. Navarro
# Licensed under AGPL-3.0 — https://www.gnu.org/licenses/agpl-3.0.html
class MqttPublisher
  TOPIC_PREFIX = "mikhael/devices".freeze

  def self.publish(device, payload)
    url = ENV["MQTT_URL"].presence
    return unless url

    topic = "#{TOPIC_PREFIX}/#{device.device_id}/command"

    MQTT::Client.connect(url) do |client|
      client.publish(topic, payload.to_json, retain: false, qos: 1)
    end

    Rails.logger.info("MQTT → #{topic}: #{payload.to_json}")
  rescue MQTT::Exception, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error("MQTT publish failed (#{topic}): #{e.message}")
  end
end

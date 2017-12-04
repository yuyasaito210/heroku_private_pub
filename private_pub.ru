# Run with: rackup private_pub.ru -s thin -E production
require "bundler/setup"
require "yaml"
require "faye"
require "private_pub"
require 'net/http'    

Faye::WebSocket.load_adapter('thin')

PrivatePub.load_config(File.expand_path("../config/private_pub.yml", __FILE__), ENV["RAILS_ENV"] || "production")
app = PrivatePub.faye_app

# subscribe - online
app.bind(:subscribe) do |client_id, channel|
  puts "Client subscribe: #{client_id}:#{channel}"

  if channel.split('/')[1] == "push"
    user_id = channel.split('/').last
    puts "user_id: #{user_id}"
    Thread.new do
      PrivatePub.publish_to "/presence", {:id => user_id, :online => true}
    end
  end

end

# unsubscribe - offline
app.bind(:unsubscribe) do |client_id, channel|
  puts "Client unsubscribe: #{client_id}:#{channel}"
  if channel.split('/')[1] == "push"
    user_id = channel.split('/').last
    Thread.new do
      PrivatePub.publish_to "/presence", {:id => user_id, :online => false}
    end
  end
end

# disconnect - offline
app.bind(:disconnect) do |client_id, channel|
  puts "Client disconnect: #{client_id}:#{channel}"
  puts "Nothing"
end


run app
# Run with: rackup private_pub.ru -s thin -E production
require "bundler/setup"
require "yaml"
require "faye"
require "private_pub"
require 'net/http'    

Faye::WebSocket.load_adapter('thin')

PrivatePub.load_config(File.expand_path("../config/private_pub.yml", __FILE__), ENV["RAILS_ENV"] || "production")
app = PrivatePub.faye_app

@prefix_url = "http://localhost:3000"
@set_status_url = "/presence/set_state"

def send_user_status_with_http(client_id, online)
	uri = URI("#{@prefix_url}#{@set_status_url}?id=#{client_id}&online=#{online}")
	puts "uri = #{uri}"
	res = Net::HTTP.start(uri.hostname, uri.port) {|http|
		request = Net::HTTP::Get.new(uri)
		puts "send to ..."
		response = http.request request
		puts response
	}
end

def send_user_status_with_https(client_id, online)
	uri = URI("#{@prefix_url}#{@set_status_url}?id=#{client_id}&online=#{online}")
	Net::HTTP.start(uri.host,
	                uri.port,
	                :use_ssl => uri.scheme == 'https',
	                :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
	  request = Net::HTTP::Get.new uri.request_uri
	  response = http.request request
	  puts response.inspect
	end
end

# subscribe - online
app.bind(:subscribe) do |client_id, channel|
  puts "Client subscribe: #{client_id}:#{channel}"
	# send_user_status_with_http(client_id, true)

  if channel.split('/')[1] == "push"
    user_id = channel.split('/').last
    puts "user_id: #{user_id}"
    Thread.new do
    	# send_user_status_with_http(user_id, true)
      PrivatePub.publish_to "/presence", {:id => user_id, :online => true}
    end
  end

  if /\/user\/*/.match(channel)
    p "ok ****8"
    # send user status to crebels server
    # SubscribeClient.perform_async(client_id, channel)
  end
end

# unsubscribe - offline
app.bind(:unsubscribe) do |client_id, channel|
  puts "Client unsubscribe: #{client_id}:#{channel}"
  if channel.split('/')[1] == "push"
    user_id = channel.split('/').last
    # redis.set("user_#{user_id}_online", false)
    Thread.new do
    	# send_user_status_with_http(user_id, false)
      PrivatePub.publish_to "/presence", {:id => user_id, :online => false}
    end
  end
  # UnsubscribeClient.perform_async(client_id)
end

# disconnect - offline
app.bind(:disconnect) do |client_id, channel|
  puts "Client disconnect: #{client_id}:#{channel}"
  # send_user_status_with_http(client_id, false)
  # UnsubscribeClient.perform_async(client_id)
end


run app
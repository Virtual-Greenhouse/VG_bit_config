require 'concurrent'
require 'socket'
require 'json'

class GreenHouseData
  attr_reader :counter, :data
  attr_accessor :pending_command
  MAX_SIZE = 4

  def initialize
    @counter = 0
    @data = []
    @pending_command = "waiting"
  end

  def store_data(data_to_store)
    if @counter == MAX_SIZE
      @counter = 0
    end
    @data[@counter] = data_to_store
    @counter += 1
  end

  def get_data
    @data
  end

  def get_latest_data
    @data[@counter - 1]
  end

  def get_oldest_data
    data[@counter]
  end
end

###############

server = TCPServer.open('0.0.0.0', 9002)
puts "starting server"

data_hash = Concurrent::Map.new

green_house_recv_thread = Thread.new do
  loop do
    ruby_client = server.accept
    response = ruby_client.gets
    puts(response)
    parsed_data = JSON.parse(response)
    id = parsed_data["id"]
    # puts response
    # ruby_client.puts("sup dawg") #send a single number to execute an action -> the potato/python will have functions to determine what to do
  
    if data_hash.fetch(id, nil).nil?
      data_hash[id] = GreenHouseData.new
      puts "Created new greenhouse object with id #{id}"
    end
  
    data_hash[id].store_data(parsed_data)

    command = data_hash[id].pending_command
    puts command
    if command != "waiting"
      ruby_client.puts(command)
      puts "send command #{command}"
      data_hash[id].pending_command = "waiting"
      
    end

    ruby_client.close
    puts data_hash[id].get_data
    puts
  end
end


########
# start framework thread: 

rails_listener_thread = Thread.new do 
  listener = TCPServer.open('0.0.0.0', 9010)
  puts "starting framework listener"

  loop do
    client = listener.accept
    response = client.gets.chomp
    puts("Recvd cmd: #{response}")
    #TODO:
    # in rails, make a hash containing the id and command
    # then parse the response here, which will be a JSON and convert back into a hash again

    id = "green1"
    case response 
    when "get_info"
      puts "received command get_info" # gets data
      json_response = data_hash[id].get_data.to_json #will this crash calling .to_json on an array?yes
      client.puts(json_response)
    when "light_on"
      puts "received command light on"
      data_hash[id].pending_command = "light_on"
    when "light_off"
      puts "received command light_off"
      data_hash[id].pending_command = "light_off"
    end
  end
end

#######

# This is the code you will put into rails, but dont make the thread
# Thread.new do
#   sleep(10)
#   i_am_rails = TCPSocket.open('localhost', 9010)
#   puts("IAMRAILS: sending command 0")
#   i_am_rails.puts("0")
#   data_from_the_data_service = i_am_rails.gets
#   puts("IAMRAILS: Recvd data back! [#{data_from_the_data_service}]")
# end

green_house_recv_thread.join
rails_listener_thread.join

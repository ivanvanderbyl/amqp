# -*- coding: utf-8 -*-
require "spec_helper"

describe "Exclusive server-named queue" do

  #
  # Environment
  #

  include AMQP::Spec

  default_timeout 1

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open

    @exchange = AMQP::Exchange.default(@channel)
  end



  it "can be used for temporary point-to-point communication" do
    @exchange.channel.should == @channel

    @channel.queue("", :exclusive => true) do |queue1|
      @channel.queue("", :exclusive => true) do |queue2|
        request_timestamp = Time.now
        reply_timestamp   = nil

        queue1.subscribe do |header, body|
          header.timestamp.to_i.should == request_timestamp.to_i
          header.app_id.should == "Client"
          header.reply_to.should == queue2.name

          reply_timestamp = Time.now
          @exchange.publish(rand(1000), :routing_key => header.reply_to, :reply_to => queue1.name, :app_id => "Server", :timestamp => reply_timestamp)
        end

        queue2.subscribe do |header, body|
          header.timestamp.to_i.should == reply_timestamp.to_i
          header.app_id.should == "Server"
          header.reply_to.should == queue1.name
        end


        # publish the request
        @exchange.publish(rand(1000),
                          :routing_key => queue1.name,
                          :reply_to    => queue2.name,
                          :app_id      => "Client",
                          :timestamp   => request_timestamp,
                          :mandatory   => true,
                          :immediate   => true)

        done(0.1) {
          queue1.unsubscribe
          queue2.unsubscribe
        }
      end # do      
    end # do
  end # it
end # describe

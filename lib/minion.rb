require 'uri'
require 'json' unless defined? ActiveSupport::JSON
require 'mq'
require 'bunny'
require 'minion/handler'

module Minion
  
  class AMQPServerConnectError < StandardError; end;
  
  NUMBER_OF_RETRIES = 3
  
	extend self

	def url=(url)
		@@config_url = url
	end

  def enqueue(jobs, data = {})
    raise "cannot enqueue a nil job" if jobs.nil?
    raise "cannot enqueue an empty job" if jobs.empty?

    ## jobs can be one or more jobs
    if jobs.respond_to? :shift
      queue = jobs.shift
      data["next_job"] = jobs unless jobs.empty?
    else
      queue = jobs
    end

    # NOTE: we encode to yaml, Minion encodes to json.  The reason is that json cannot handle Ruby symbols    
    yamlized_data = data.to_yaml
    log "send: #{queue}:#{yamlized_data}"

    # NOTE: When rabbitMQ goes down, the mongrel keeps on holding the stale connection to it. We need to establish a new
    # connection when this happens.
    
    with_bunny_connection_retry do
      bunny.queue(queue, :durable => false, :auto_delete => false).publish(yamlized_data)
    end
  end

	def log(msg)
		@@logger ||= proc { |m| puts "#{Time.now} :minion: #{m}" }
		@@logger.call(msg)
	end

	def error(&blk)
		@@error_handler = blk
	end

	def logger(&blk)
		@@logger = blk
	end

	def job(queue, options = {}, &blk)
		handler = Minion::Handler.new queue
		handler.when = options[:when] if options[:when]
		handler.unsub = lambda do
			log "unsubscribing to #{queue}"
			MQ.queue(queue, :durable => false, :auto_delete => false).unsubscribe
		end

		handler.sub = lambda do
			log "subscribing to #{queue}"
			MQ.queue(queue, :durable => false, :auto_delete => false).subscribe(:ack => false) do |h,m|
				return if AMQP.closing?
				begin
					log "recv: #{queue}:#{m}"

					args = decode_json(m)

					result = yield(args)

					next_job(args, result)
				rescue Object => e
					raise unless error_handler
					error_handler.call(e,queue,m,h)
				end
				check_all
			end
		end
		@@handlers ||= []
		at_exit { Minion.run } if @@handlers.size == 0
		@@handlers << handler
	end

	def decode_json(string)
		if defined? ActiveSupport::JSON
			ActiveSupport::JSON.decode string
		else
			JSON.load string
		end
	end

	def check_all
		@@handlers.each { |h| h.check }
	end

  def run
    log "Starting minion"

    Signal.trap('INT') { exit_handler }
    Signal.trap('TERM'){ exit_handler }

    EM.run do
      connection = AMQP.start(amqp_config) do
        MQ.prefetch(1)
        check_all
      end
      
      # NOTE: By default, Minion gets into a wierd state when there is a connection error (i.e., the AMQP server is down).  
      # In short, it continues running without any subscriptions. We chose to detect this case, and kill the worker that
      # has invoke run. This will allow it to be restarted by the monitoring system, and hopefully by then, the AMQP
      # server will be back up. 
      if connection.error?
        exit_handler
        raise AMQPServerConnectError.new("Couldn't connect to RabbitMQ server at #{amqp_url}")
      end
    end
  end

	def amqp_url
		@@amqp_url ||= ENV["AMQP_URL"] || "amqp://guest:guest@localhost/"
	end

  def amqp_url=(url)
    clear_bunny
    @@amqp_url = url
  end
  
  def delete!(*queue_names)
    EM.run do 
      AMQP.start(amqp_config) do
        queue_names.each do |queue_name|
          MQ.queue(queue_name).delete
          msg = "Minion: deleting '#{queue_name}' queue from the AMQP server."
          ActiveRecord::Base::logger.info(msg)
          log msg
        end
      end

      AMQP.stop { EM.stop }
    end

  end
  
  def with_bunny_connection_retry
    num_executions = 1 
    begin
      yield
    rescue Bunny::ServerDownError, Bunny::ConnectionError => e
      clear_bunny
      if num_executions < NUMBER_OF_RETRIES
        log "Retry ##{num_executions}  : #{caller.first}"
        num_executions += 1
        sleep 0.5
        retry
      else
        error = e.class.new(e.message + " (Retried #{NUMBER_OF_RETRIES} times.  Giving up.)")
        error.set_backtrace(e.backtrace)
        raise error
      end
    rescue => e
      clear_bunny
      raise e
    end            
  end

  def clear_bunny
    @@bunny = nil    
  end

	private

	def amqp_config
		uri = URI.parse(amqp_url)
		{
			:vhost => uri.path,
			:host => uri.host,
			:user => uri.user,
			:port => (uri.port || 5672),
			:pass => uri.password
		}
	rescue Object => e
		raise "invalid AMQP_URL: #{uri.inspect} (#{e})"
	end

	def new_bunny
		b = Bunny.new(amqp_config)
		b.start
		b
	end

	def bunny
		@@bunny ||= new_bunny
	end

	def next_job(args, response)
		queue = args.delete("next_job")
		enqueue(queue,args.merge(response)) if queue and not queue.empty?
	end

	def error_handler
		@@error_handler ||= nil
	end
	
	def exit_handler
    AMQP.stop { EM.stop } 
  end  
  
end


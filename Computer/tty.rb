# https://gist.github.com/mqu/f32599117f1fa21c1b2c
require "serialport"

class TTy

	def initialize

		# defaults params for arduino serial
		baud_rate = 115200
		data_bits = 8
		stop_bits = 1
		parity = SerialPort::NONE

		# serial port
		@sp=nil
		@port=nil
	end
	
	def open port
		@sp = SerialPort.new(port, @baud_rate, @data_bits, @stop_bits, @parity)
	end
	
	
	def shutdown reason

		return if @sp==nil
		return if reason==:int

		printf("\nshutting down serial (%s)\n", reason)

		# you may write something before closing tty
		@sp.write(0x00)
		@sp.flush()
		printf("done\n")
	end
	
	def read
		@sp.flush()
		printf("# R : reading ...\n")
		c=nil
		while c==nil
			c=@sp.read(1)
			break if c != nil
		end
		printf("# R : 0x%02x\n", c.ord)
		return c
		# @sp.readByte()
	end
	
	def write c
		@sp.putc(c)
		@sp.flush()
		printf("# W : 0x%02x\n", c.ord)
	end
	
	def flush
		@sp.flush
	end
end

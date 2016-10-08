#!/usr/bin/ruby
require 'webrick'
require 'json'

class Object
	def transform(&b)
		yield self
	end
end

def disk_usage
	`df`.split("\n")[1..-1].map { |x| x.split(/\s+/) }.map do |x|
		{
			filesystem:   x[0],
			size:         x[1],
			used:         x[2],
			available:    x[3],
			used_percent: x[4],
			mountpoint:   x[5],
		}
	end
end

def memory_usage
	`free -o`.split("\n")[1..-1].map{ |x| x.split(/\s+/) }.map do |x|
		{
			name: x[0],
			total: x[1],
			used: x[2],
			free: x[3],
			shared: x[4],
			buffers: x[5],
			cached: x[6]
		}
	end
end

def temperature
	[{
		name: "CPU Temp",
		value: (Process.uid == 0 ? `/opt/vc/bin/vcgencmd measure_temp`.sub(/^temp=/,'').sub("'",'°') : File.read("/usr/share/rpimon/temp"))
	}]

end

def cpu_usage
	if Process.uid == 0
		[{core: "All", load: `mpstat | awk '$12 ~ /[0-9.]+/ { print 100 - $12 }'`.strip}]
	else
		`mpstat -P ALL 1 1`.split("\n\n")[1].split("\n")[1..-1].map do |x|
			x = x.split(/[^\d\.%:a-zA-Z]+/)
			{
				core:x[1],
				load:100.0 - x[11]
			}
		end
	end
end

def logged_in
	`w`.split("\n")[2..-1].map{ |x| x.split(/\s+/) }.map do |x|
		{
			user: x[0],
			tty: x[1],
			from: x[2],
			login_time: x[3],
			idle: x[4],
			jcpu: x[5],
			pcpu: x[6],
			what: x[7]
		}
	end
end

def uptime
	`uptime -p`.sub(/^up/,'')
end

require 'optparse'

Options = Struct.new(:verbose,:port,:auth_url,:default_display)

options = Options.new(false,1337,nil,"load,mem,disk,temp,up,who")
puts options

RMON_VER = "0.1.0"

OptionParser.new do |opts|
	opts.banner = "RPiMon API Server v#{RMON_VER}"

	opts.on("-v","--version","Print version and exit") do
		puts RMON_VER
		exit
	end

	opts.on("-V","--verbose","Run verbosely") do
		options.verbose = true
	end

	opts.on("-pPORT","--port=PORT", "Run on port PORT (default 1337)") do |port|
		options.port = port.to_i
	end

	opts.on("-aURL","--auth=URL", "Use URL as auth API URL") do |url|
		options.auth_url = url
	end

	opts.on("-sSTR","--show-default=STR", "Set default displayed values to STR" ) do |s|
		options.default_display = s
	end

	opts.on("-cFILE","--conf=FILE","Use config file") do |f|
		if File.exists?(f)
			json = JSON.parse File.read f
			options.default_display = json[:default_display]
			options.auth_url = json[:auth_url]
			options.port = json[:port]
			options.verbose = json[:verbose]
		else
			puts "Warning : no config file"
		end
	end

	opts.on("-h","--help","Print this help and exit") do
		puts opts
		exit
	end
end.parse!

server = WEBrick::HTTPServer.new :Port => options.port

trap 'INT' do
	server.shutdown
end

trap 'TERM' do
	server.shutdown
end

server.mount_proc '/' do |req, res|
	result = {:rmon_version => RMON_VER}
	begin
		req.query['show'] ||= options.default_display
		for val in req.query['show'].split(",")
			case val
			when "load"
				result[:cpu_usage] = cpu_usage
			when "mem"
				result[:memory_usage] = memory_usage
			when "disk"
				result[:disk_usage] = disk_usage
			when "temp"
				result[:temperature] = temperature
			when "up"
				result[:uptime] = uptime
			when "who"
				result[:logged_in] = logged_in
			end
		end
		res.status = 200
		res.body = JSON.pretty_generate result
	rescue => e
		res.status = (req.query["catch"] ? 200 : 500)
		res.body = JSON.pretty_generate error: true, backtrace: e.backtrace, summary:e.to_s
	end
	res['Content-Type'] = "application/json; charset=#{Encoding.find("locale").name.downcase}"
end

server.start

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
	if Process.uid == 0
		`/opt/vc/bin/vcgencmd measure_temp`.sub(/^temp=/,'').strip
	else
		File.read("/etc/rmon/temp")
	end
end

def cpu_usage
	`mpstat | awk '$12 ~ /[0-9.]+/ { print 100 - $12 }'`.strip
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
	`uptime`.strip.match(/up (?<uptime>.*),\s+\d+ user/).transform do |md|
		days = md[:uptime].match(/(?<d>\d+) days/)
		days = days ? days[:d] : 0
		time = md[:uptime].match(/(?<h>\d{1,2}):(?<m>\d{1,2})/)
		if time
			hours,minutes = time[:h].to_i, time[:m].to_i
		else
			hours,minutes = 0,0
		end
		{ days: days, hours: hours, minutes: minutes }
	end
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

	opts.on("-h","--help","Print this help and exit") do
		puts opts
		exit
	end
end.parse!

server = WEBrick::HTTPServer.new :Port => options.port || 1337

trap 'INT' do
	server.shutdown
end

trap 'TERM' do
	server.shutdown
end

server.mount_proc '/' do |req, res|
	result = {}
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

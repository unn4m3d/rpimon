#!/bin/sh
### BEGIN INIT INFO
# Provides:          rpimon
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       RPiMonitoring
### END INIT INFO

RPIMON_DIR="/usr/share/rpimon"

PIDFILE="/var/run/rpimon.pid"
LOGFILE="/var/log/rpimon.log"
RUNAS="root"

proc_id()
{
	ps aux | grep "$RPIMON_DIR" | grep --invert-match grep | awk '{print $2}' | grep "$(cat $PIDFILE)"
}

is_running()
{
	return [ ! -z "$(proc_id)"]
}

start(){
	if [ -f "$PIDFILE" ] && is_running; then
		echo 'Service already running' >&2
		return 1
	fi

	su -c "$RPIMON_DIR/rmon.rb --conf=$RPIMON_DIR/rpimon.json > $LOGFILE" $RUNAS > "$PIDFILE"
	echo "Started"
}

stop() {
	if [ ! -f "$PIDFILE" ] || ! is_running then
		echo 'Service not running' >&2
		return 1
	fi
	echo 'Stopping service…' >&2
	(proc_id | xargs kill -15) && rm -f "$PIDFILE"
	echo 'Service stopped' >&2
}

case $1 in
	start)
		start
	;;	
	stop)
		stop
	;;
	restart|reload)
		stop
		start
	;;
	*)
		echo "Usage : $0 (start|stop|restart|reload)"
	;;
esac
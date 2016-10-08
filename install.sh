#!/bin/sh
echo "######################################################"
echo "##################[RPiMon Installer]##################"
echo "######################################################"
echo "Installing init script"
cp ./init.sh /etc/init.d/rpimon
chmod +x /etc/init.d/rpimon
echo "Installing RPiMon to /usr/share/rpimon"
if [ ! -e /usr/share/rpimon ]; then
	echo "Making directory /usr/share/rpimon"
	mkdir -p /usr/share/rpimon
fi
cp ./rmon.rb /usr/share/rpimon/rmon.rb
if [ ! -z "$USE_RUBY" ]; then
	echo "Using $USE_RUBY instead of /usr/bin/ruby"
	sed -i 's/#!\/usr\/bin\/ruby/#!'$(echo $USE_RUBY|sed 's/\//\\\//g')'/' /usr/share/rpimon/rmon.rb 
fi
chmod +x /usr/share/rpimon

echo "Enabling launching on boot"
update-rc.d rpimon defaults
echo "######################################################"
rmon
==

*RMon* is a small daemon for getting system info through HTTP.

Its name means *RaspberryPi Monitoring* (or *Ruby Monitoring*), because it's originally developed for Raspberry Pi (tested on RPi2).

At the moment, it needs `/opt/vc/bin/vcgencmd` to be present (to read temperature).

Installation
--

RMon depends on ruby and mpstat (`sysstat` package in APT-based systems)

```sh
sudo apt install ruby2.1 sysstat #You may install any ruby 2.*
```

Running
--

```sh
sudo ruby ./rmon.rb
```

You may see commandline keys list by running `./rmon.rb -h`

Todo
--

1. Documentation
2. Init scripts
3. Reading temperature from other sources, such as `lm-sensors`

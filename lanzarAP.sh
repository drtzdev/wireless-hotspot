#!/bin/bash

xterm -geometry 93x31+100+350 -e bash -c 'dnsmasq -C /etc/dnsmasq.d/dnsmasq.conf -H /etc/dnsmasq.d/fakehosts.conf -d; exec bash' &
xterm -geometry 93x31+700+350 -e bash -c 'hostapd /etc/hostapd/hostapd.conf; exec bash' &


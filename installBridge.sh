#!/bin/bash
# Script to Install WiFi to Ethernet Bridge
#
# This script is created to work with Pi 4 - Raspbian Buster
# It is used to bridge a wifi link with connection to the internet
# to a private ethernet subnetwork.
#
# Author:
#   (C) Ron K. Irvine, 2020. All rights reserved.

# Please modify the variables according to your need
wlan="wlan0"				# WiFi link with internet access
eth="eth0"					# Ethernet sub-network
ip_address="192.168.22.1"
ip_router="192.168.22.0"
netmask="255.255.255.0"
dhcp_range_start="192.168.22.100"
dhcp_range_end="192.168.22.199"
dhcp_time="12h"

printf "Setup Bridge from $wlan to $eth\n"
printf "Static IP: $eth:$ip_address\n"
printf "DHCP Range: $eth:$dhcp_range_start to $dhcp_range_end\n"
sleep 2.5

printf "Install dnsmasq:\n"
# sudo apt-get update
# sudo apt-get upgrade

# sudo apt-get install dnsmasq -y
dpkg -s dnsmasq 2>/dev/null >/dev/null || sudo apt-get install -y dnsmasq
dpkg -s dnsmasq | grep Status


printf "$wlan - Network Configuration:\n"
cat /etc/wpa_supplicant/wpa_supplicant.conf | grep "ssid="

dhcpFile=/etc/dhcpcd.conf
printf "=====  $dhcpFile  =====\n"
if [ ! -f $dhcpFile.sav ]; then
    echo Backup: $dhcpFile
    sudo mv $dhcpFile $dhcpFile.sav
fi

sudo bash -c "cat >$dhcpFile" <<EOF
# Create a static IP for eth0
interface $eth
static ip_address=$ip_address/24
static routers=$ip_router
EOF

printf "dhcpFile:\n"
cat "$dhcpFile"

printf "Restart dhcpcd service ... wait\n"
sudo service dhcpcd restart
printf "Restart done.\n"

dnsFile=/etc/dnsmasq.conf
printf "=====  $dnsFile  =====\n"
if [ ! -f $dnsFile.sav ]; then
    echo Backup: $dnsFile
    sudo mv $dnsFile $dnsFile.sav
fi
# ls /etc/*.sav

sudo rm $dnsFile

if [ ! -f $dnsFile ]; then
sudo cp $dnsFile.sav $dnsFile
sudo bash -c "cat >>$dnsFile" <<EOF

# Add DNS and DHCP bridge traffic
interface=$eth			# Use interface eth0
listen-address=$ip_address	# Specify the address to listen on
# bind-interfaces		# Bind to the interface
server=8.8.8.8			# Use Google DNS
domain-needed			# Don't forward short names
bogus-priv			# Drop the non-routed address spaces.
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time	# IP range and lease time
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
EOF
fi

printf "$dnsFile:\n"
# cat $dnsFile
diff $dnsFile.sav $dnsFile

sysFile=/etc/sysctl.conf
printf "=====  $sysFile  =====\n"
if [ ! -f $sysFile.sav ]; then
    sudo cp -p $sysFile $sysFile.sav 
fi
printf "\n"
printf "$sysFile - Set ip4 forwarding:\n"
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' $sysFile
cat $sysFile | grep "ip_forward"

# ls -la /etc/*.sav

# Forward Immediately
sudo sh -c "echo 1 >/proc/sys/net/ipv4/ip_forward"

printf "=====  Update iptables  =====\n"
natFile=/etc/iptables.ipv4.nat
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -o $wlan -j MASQUERADE  
sudo iptables -A FORWARD -i $wlan -o $eth -m state --state RELATED,ESTABLISHED -j ACCEPT  
sudo iptables -A FORWARD -i $eth -o $wlan -j ACCEPT
sudo sh -c "iptables-save >$natFile"
# printf "$natFile:\n"
# cat $natFile
printf "iptables rules:\n"
sudo iptables --list-rules

# enable NAT on startup

rcFile=/etc/rc.local
printf "=====  $rcFile  =====\n"
if [ ! -f $rcFile.sav ]; then
    echo Backup: $rcFile
    sudo mv $rcFile $rcFile.sav
fi

if grep -q "iptables-restore" "$rcFile"; then
    echo Already setup: $rcFile
else
    echo Setup: $rcFile
    sudo sed -i "/^exit 0.*/i iptables-restore <$natFile" $rcFile
fi
printf "Diff $rcFile:\n"
diff $rcFile.sav $rcFile
printf "\n"

printf "=====  Restart dnsmasq  =====\n"
sudo service dnsmasq start
printf "Restarted ...\n"

printf "Saved file:\n"
ls -la /etc/*.sav

printf '=====  Look for Gateway  =====\n'
sleep 3
# Verify the Gateway is ok
# use the 'ip route' command to get the gateway's IP address
#       an empty string if no gateway
nloop=0
while [ $nloop -lt 10 ]; do
	gateway=$(ip route | grep "default via" | cut -d ' ' -f 3)
	if [ ! -z "$gateway" ]; then
    	break
	fi
    printf "Wait for gateway ...\n"
	sleep 1.5
    nloop=`expr $nloop + 1`
done

# gateway=$(ip route | grep "default via" | cut -d ' ' -f 3)
device=$(ip route | grep "default via" | cut -d ' ' -f 5)
if [ -z "$gateway" ]; then
    printf "ERRROR - Gateway Not Found...\n"
    exit 1
else
    printf "Ping Gateway: $gateway - $device\n"
    ping -q -w 1 -c 1 $gateway >/dev/null 2>/dev/null
    ret=$?
    if [[ $ret -eq 0 ]]; then
        echo Gateway $gateway - Ok!
    else
        printf "Unable to ping the gateway: $gateway\n"
        exit $ret
    fi
fi

printf "=====  Connection Status  ======\n"
google=8.8.8.8
nloop=0
while ! ping -q -c 1 -W 1 $google && [ $nloop -lt 10 ]; do
    echo "$nloop - Waiting for $google - Network down?"
    sleep 1
    nloop=`expr $nloop + 1`
done

printf "=====  Ping the Gateway  =====\n"
gateway=`ip r | grep default | cut -d ' ' -f 3`
if [ ! -z "$gateway" ]; then
        ping -q -w 1 -c 1 $gateway > /dev/null && echo Gateway $gateway - Ok! || echo Ga$
fi

printf "=====  arp  ======\n"
arp


printf "=====  Done!  =====\n"



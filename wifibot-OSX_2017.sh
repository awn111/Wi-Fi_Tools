#!/bin/bash -e

### File locations for wifi stats & log file

STATSFILE="/Users/andrew/wifibot-stats_$(date +"%m%d%Y").csv"            # wifi stats file 
LOG="/Users/andrew/wifibot.log"                			# log any events etc on file operation 

# Script to monitor client side wireless performance 

### Default Settings and Variable

VER=0.6.0 	# 2017	
SLEEP=1		# default delay interval between samples
COUNT=5		# default number of samples
QUIET=0	   	# default quiet mode, 0 quiet disabled, 1 enabled 
SIZE=500     	# size of ping file for rtt tests
STATS=0		# default for creating stats file, 0 disalbed, 1 enabled

### Set option from arguments

while getopts "fqhv:c:i:s:" opt; do 

     case $opt in 
	  f) STATS=1;;
          i) SLEEP="$OPTARG" ;;
          c) COUNT="$OPTARG" ;;
          q) QUIET=1 ; STATS=1;;
          s) SIZE="$OPTARG";;
          h) 
                echo 
		echo "usage: $0 [-c <count> -i <interval 0.1 to X  ] "  
                echo 
                echo      -f    create stats file 
                echo      -q 	quiet, supresses output to screen, assumes -f 
                echo 
                echo      -c number : stop after reporting c samples
                echo      -i number : time between samples 0.1 or greater
                echo      -s number : packetsize in bytes for active checks
                echo 
		echo "example: $0 -c 5 -i 1 -s 1200" 
		echo "example: $0 -c 6 -i 10 -q"
                echo
		exit 0;; 
     esac    
done
shift $(expr $OPTIND - 1)

COUNTER=1               # Used for repeat loop

### Write paramaters to screen 

if [ $QUIET == 0 ] ; then
	echo ; echo Using gateway $hostGW, dns $hostDNS, interval: $SLEEP, count: $COUNT ; echo
	if [ STATS == 1 ] ; then 
		echo Stats file is $STATSFILE
	fi
fi

### Create stats file and write coloums to stats file if stats enabled and file does not exist. 

if [ STATS == 1 ] ; then 
     if [ ! -f $STATSFILE ]; then
          echo time, SSID, channel, SNR, rssi, noise, bssid, MCS, txRate, txMaxRate, gwRtt, gwHost, gDNSRtt, dnsHost >> $STATSFILE
     fi
fi

### Output columns to screen 

if [ $QUIET == 0 ] ; then
     echo time, SSID, channel, SNR, rssi, noise, bssid, MCS, txRate, txMaxRate, gwRtt, gwHost, gDNSRtt, dnsHost 
fi

### Main loop for stats collection

while [  $COUNTER -le $COUNT ]; do

### Identify DNS and Gateway - may change while executing, check each time

       hostDNS=$(/usr/bin/dig | grep SERVER | awk '{print $3}' | cut -d "#" -f 1)
       hostGW=$(/usr/sbin/netstat -rn | grep def |awk '{print $2}')

# Active checks for rtts to GW & DNS

     pingGW=$(/sbin/ping -c 1 $hostGW    | grep "bytes from" | awk '{print $7}' | cut -d"=" -f 2)
     pingDNS=$(/sbin/ping -c 1 $hostDNS  | grep "bytes from" | awk '{print $7}' | cut -d"=" -f 2)

# Collect data using the 'airport -I' command

	   RAWRSSI=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep CtlRSSI | cut -d "-" -f2 )

	   BSSID=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep BSSID | sed s/"D: "/Dx/ | cut -d "x" -f 2 )

	   agrCtlNoise=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep agrCtlNoise | cut -d ":" -f2)
	   RAWagrCtlNoise=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep agrCtlNoise | cut -d "-" -f2)

	   SSID=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " SSID" | sed s/"D: "/D@/ | cut -d "@" -f 2)

	   txRate=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep lastTxRate | cut -d ":" -f2 )

	   MCS=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep MCS | cut -d ":" -f 2 )

	   maxRate=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep maxRate | cut -d ":" -f2 )

        channel=$( /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep channel | sed s/"l: "/,/ | cut -d , -f 2 )

        int=$( /usr/sbin/netstat -rn | grep default | awk '{print $6}' )

        SNR=$((RAWagrCtlNoise - RAWRSSI))

	HOSTNAME=$(/bin/hostname)  					# hostname for server call to ID bot 
	MAC=$(/sbin/ifconfig $int | grep ether | awk {'print $2'})	# MAC for server call to ID bot
	IP=$(/sbin/ifconfig $int | grep inet | awk {'print $2'}) 	# IP for server call to verify LAN 

if [ $STATS == 1 ] ; then 
	echo $(date +"%T"), $SSID, $channel, $SNR, -$RAWRSSI, $agrCtlNoise, $BSSID, $MCS, $txRate,$maxRate, $pingGW, $hostGW, $pingDNS, $hostDNS  >> $STATSFILE
fi 

if [ $QUIET == 0 ] ; then 
	echo $(date +"%T"), $SSID, $channel, $SNR, -$RAWRSSI, $agrCtlNoise, $BSSID, $MCS, $txRate, $maxRate, $pingGW, $hostGW, $pingDNS, $hostDNS 
fi    
    let COUNTER=COUNTER+1
    sleep $SLEEP

done

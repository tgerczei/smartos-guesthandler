#!/usr/bin/env bash
# implement guest start-up and shutdown order to ensure proper operation
# PREREQUISITE: 'vmadm update $UUID <<< "{\"set_tags\": {\"priority\": 0}}"' where 0 means 'OFF', the rest determines ascending and descending numerical order respectively

. /lib/svc/share/smf_include.sh

if [ -z "$SMF_FMRI" ]; then
    echo "this script can only be invoked by smf(5)"
    exit $SMF_EXIT_ERR_NOSMF
fi

ME=$(basename ${0%.sh})

# start-up delay between VMs
DELAY=30

function log	{
		# helper function to log arbitrary messages via syslog
		logger -p daemon.notice -t $ME $@
		}

case $1 in
	start)
		# determine the order of VMs by boot priority
		ORDER=( $(vmadm lookup -j -o uuid,tags | json -c 'this.tags.priority > 0' -a uuid tags.priority | sort -nk2 | cut -d " " -f1) )
		# start guests
		for UUID in ${ORDER[*]}
			do
				# invoke vmadm
					vmadm start $UUID 2> /dev/null
					if [ $? -eq 0 ]
					then
						# successful start, log and wait
						log $UUID managed to $1
						sleep $DELAY
					else
						# failed to start guest
						log $UUID failed to $1
					fi
			done
	;;

	stop)
		# determine the order of VMs by reverse boot priority
		ORDER=( $(vmadm lookup -j -o uuid,tags state=running | json -a uuid tags.priority | sort -rnk2 | cut -d " " -f1) )
		# stop guests
		for UUID in ${ORDER[*]}
			do
				# invoke vmadm
				vmadm stop $UUID 2> /dev/null
				if [ $? -eq 0 ]
					then
						# successful stop
							log $UUID managed to $1
					else
						# failed to stop guest
							log $UUID failed to $1
				fi
			done
	;;

	disarm)
		# set the 'autoboot' attribute to 'false' for every installed guest on order to prevent automatic start-up without this script
		zoneadm list -pi | while IFS=":" read ID UUID STATE remainder; do
			if [[ $STATE == "installed"  ]];
				then
					zonecfg -z $UUID set autoboot=false
			fi
		done
		log disarmed: set autoboot=false on all zones
	;;

	*)
		exit 1;
esac

exit $SMF_EXIT_OK

#!/bin/bash
set -e

while :; do
	case $1 in
		-v)
			VERBOSE=1
			shift
			;;
		-l)
			LOG=1
			shift
			;;
		*)
			break
	esac
done

# Which GPIO pin being used to control the fan
if [ -n "$1" ]; then

	FAN_PIN="$1"
else
	echo "Usage: $0 [GPIO Pin] <On Threshold> <Off Threshold>"
	echo 'Flags: -v   Verbose (display to screen)'
	echo '       -l   Log (write to log file)'
	exit 1
fi

if [ -n "$2" ]; then
	ON_THRESHOLD="$2"
else
	ON_THRESHOLD=65
fi

if [ -n "$3" ]; then
	OFF_THRESHOLD="$3"
else
	OFF_THRESHOLD=$(( $ON_THRESHOLD - 10 ))
fi

if [ $ON_THRESHOLD -le $OFF_THRESHOLD ]; then
	local tmp=$ON_THRESHOLD
	ON_THRESHOLD=$OFF_THRESHOLD
	OFF_THRESHOLD=$tmp
fi

ON=1
OFF=0
FAN="/sys/class/gpio/gpio$FAN_PIN"

if [ ! -d "$FAN" ]; then
	echo "$FAN_PIN" > '/sys/class/gpio/export'
fi

echo 'out' > "$FAN/direction"
echo "$OFF" > "$FAN/value"

while true; do
	temp=$(vcgencmd measure_temp | awk -F "[=.]" '{print($2)}')

	if [ $temp -gt $ON_THRESHOLD ]; then
		if [ $(cat "$FAN/value") -eq $OFF ]; then
			echo $ON > "$FAN/value"
		fi

		interval=$(( $temp - $OFF_THRESHOLD + 1 ))
	elif [ $temp -lt $OFF_THRESHOLD ]; then
		if [ $(cat "$FAN/value") -eq $ON ]; then
			echo $OFF > "$FAN/value"
		fi

		interval=$(( ($ON_THRESHOLD - $temp) / 2 + 1 ))
	else
		if [ $(cat "$FAN/value") -eq $ON ]; then
			interval=$(( $temp - $OFF_THRESHOLD + 1 ))
		else
			interval=$(( ($ON_THRESHOLD - $temp) / 2 + 1 ))
		fi
	fi

	if [ $VERBOSE ]; then
		msg="($(date)) Temperature: $temp, Interval: $interval"
		if [ $LOG ]; then
			echo $msg > /usr/local/bin/cpu-fan.log 2>&1
		else
			echo $msg
		fi
	fi

	sleep $interval
done


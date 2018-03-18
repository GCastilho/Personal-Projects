#!/bin/bash

default_dir=/home/gabriel
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
UPDATE_PATH=/home/gabriel/Nabucodonosor/scripts/geth_laucher_update.sh
sh_file=.geth_instance_manager.sh
geth_network=$1
global_lauchopts=$2

updateFunction()
{
	echo "Checking for updates"
	cmp --silent $ABSOLUTE_PATH $UPDATE_PATH
	if [ $? -ne 0 ]; then
		echo "New update found, updating"
		cp $UPDATE_PATH $ABSOLUTE_PATH
		if [ $? -eq 0 ]; then
			echo "Successful update, restarting the script"
			$ABSOLUTE_PATH $geth_network $global_lauchopts
			exit 0
		else
			echo "Update error, stopping"
			exit 1
		fi
	else
		echo "No update found, continuing normally"
		return 0
	fi
}

updateFunction	#call updateFunction

start()
{
	echo "Starting"
	if [ -e $default_dir/$pid_file ]; then
		pid_content=$(cat $default_dir/$pid_file)
		kill -0 $pid_content >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Process is already running"
			echo "Use 'stop' or 'restart' instead"
			return 1
		else
			echo "Error, PID file exists but it's process not"
			rm "$default_dir/$pid_file" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Trying to start again"
				start	#chama novamente a função start
			else
				echo "Critical error, can't remove PID file"
				echo "Stopping"
				exit 1
			fi
		fi
	else
		if [ -d $HOME/$w_dir ]; then
			nohup $default_dir/$sh_file $geth_network >/dev/null 2>&1 &
			exit_status=$?
			if [ $exit_status -eq 0 ]; then
				echo "Started, no errors"
				return 0
			else
				echo "Error launching the script"
				echo "'nohup' exited with status $exit_status"
				return 1
			fi
		else
			echo "Can't find '$w_dir' folder"
			echo "Stopping"
			exit 1
		fi
	fi
}

stop ()
{
	echo "Stopping"
	if [ -e $default_dir/$pid_file ]; then
		pid_content=$(cat $default_dir/$pid_file)
		kill -2 $pid_content >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Process stopped"
			rm $default_dir/$pid_file >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "No errors"
				return 0
			else
				echo "Error deleting the PID file"
				return 1
			fi
		else
			echo "There was an error stopping the process"
			echo "Process NOT stopped"
			rm $default_dir/$pid_file >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				echo "Critical error, can't remove PID file"
				echo "Stopping"
				exit 1
			fi
			return 1
		fi
	else
		echo "Process PID not fund"
		echo "Geth isn't running or there was an error"
		return 1
	fi
}

restart ()
{
	echo "Restarting"
	if( stop && sleep 5 && start ); then
		exit 0
	else
		exit 1
	fi
}

#The script start executing *HERE*

case $geth_network in
	main|"")
		echo "Selecting geth mainnet"
		pid_file=.geth_PID.pid
		w_dir=.ethereum/geth
		geth_network=main
		;;
	light)
		echo "Selecting geth mainnet light"
		pid_file=.geth_PID.pid
		w_dir=.ethereum/geth
		;;
	test|testnet)
		echo "Selecting geth testnet"
		pid_file=.geth_testnet_PID.pid
		w_dir=.ethereum/testnet
		geth_network=test
		;;
	*)
		echo "$geth_network is an invalid argument"
		echo "Interrupting script"
		exit 2 ;;
esac

case $global_lauchopts in
	start|"")
		start
		exit
		;;
	stop)
		stop
		exit
		;;
	restart)
		restart
		exit
		;;
	*)
		echo "$global_lauchopts is an invalid argument"
		echo "Interrupting script"
		exit 2 ;;
esac
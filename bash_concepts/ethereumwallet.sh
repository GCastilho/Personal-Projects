#!/bin/bash

laucharg=$1

case $laucharg in
	main|"")
		echo "Selecting ethereum mainnet"
		network=""
		rpc_local=".ethereum/geth.ipc"
		;;
	test|testnet)
		echo "Selecting ethereum testnet"
		network="--testnet "
		rpc_local=".ethereum/testnet/geth.ipc"
		;;
	*)
		echo "$laucharg is an invalid argument"
		echo "Interrupting script"
		exit 2 ;;
esac

nohup geth $network--syncmode light --cache 512 >/dev/null 2>&1 &
exit_status=$?

if [ $exit_status -eq 0 ]; then
	echo "geth started, no errors"
else
	echo "Error launching geth"
	echo "'nohup' exited with status $exit_status"
	exit $exit_status
fi

pid=$(echo $!)
echo geth PID = $pid
ethereumwallet --rpc ~/$rpc_local >/dev/null
exit_status=$?

if [ $exit_status -eq 0 ]; then
	echo "ethereumwallet exited successfully"
else
	echo "ethereumwallet exited with status $exit_status"
	exit $exit_status
fi

kill -2 $pid >/dev/null 2>&1
exit_status=$?

if [ $exit_status -eq 0 ]; then
	echo "geth stopped successfully"
else
	echo "kill exited with status $exit_status"
	exit $exit_status
fi
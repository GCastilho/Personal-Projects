#!/bin/bash

#!/bin/bash
function finish {
	# Your cleanup code here
	echo "Worked"
}
trap finish EXIT

read -t 10
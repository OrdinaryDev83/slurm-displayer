#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

username="$1"

scancel $(squeue -u "$username" -o "%A" -S "M" -h | tail -1)

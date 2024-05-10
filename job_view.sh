#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 <user> <job_history_length> <job_slurm_logs_root_file> [-w watch_frequency] [-L]"
  echo "├─ user: The username of the user whose jobs you want to monitor"
  echo "├─ job_history_length: The number of jobs in the history to display"
  echo "├─ job_slurm_logs_root_file: The root directory where the slurm logs are stored"
  echo "├─ -w: watch_frequency: job display update delay"
  echo "└─ -L: if set, the script displays the training progress of the lightning training jobs"
}

# Check if at least three arguments are provided
if [ $# -lt 3 ]; then
  usage
  exit 1
fi

# Assigning required arguments
arg1_user=$1
arg2_jhl=$2
arg3_jslrf=$3

# Initialize default values for optional arguments
watch_frequency=1
lightning_training_scraping=false

# Shift the first three arguments to parse optional ones
shift 3

# Parse optional arguments
while getopts ":w:L" opt; do
  case ${opt} in
    w )
      watch_frequency=$OPTARG
      ;;
    L )
      lightning_training_scraping=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done

# Example function to show how to use the arguments
function process_arguments {
    watch --color -n "$watch_frequency" -x ./job_display.sh "$arg1_user" "$arg2_jhl" "$arg3_jslrf" "$lightning_training_scraping"
}

# Calling the function
process_arguments
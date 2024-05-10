# slurm-displayer
Dynamic Slurm bash displayer tailored to Siemens' Sherlock.
Features a lightning training logs scraping in order to display training progress and results.

# Usage
Usage: `./job_view.sh <user> <job_history_length> <job_slurm_logs_root_file> [-w watch_frequency] [-L]`
├─ user: The username of the user whose jobs you want to monitor"
├─ job_history_length: The number of jobs in the history to display"
├─ job_slurm_logs_root_file: The root directory where the slurm logs are stored"
├─ -w: watch_frequency: job display update delay"
└─ -L: if set, the script displays the training progress of the lightning training jobs

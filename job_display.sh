#!/bin/bash

# Define a function to fetch and display JobID, AveCPUFreq, Node Name, Partition, and Time Running    
display_job_stats() {
    # Use squeue to get list of running jobs' IDs, Partition, Node Names, and Time Running
    echo -e "\e[42m\e[97m Fetching stats for running jobs... \e[0m"
    readarray -t JOB_INFO <<< "$(squeue -u $user -t RUNNING --noheader --format='%i %18j %P %N %M %G')" 

    # Check if there are no running jobs
    if [ -z "${JOB_INFO[*]}" ]; then
        echo "No running jobs found."
        return
    fi

    # Header
    printf "%-8s\t%-18s\t%-12s\t%-16s\t%-12s\t%s\n" "JobID" "Name" "Partition" "NodeName" "TimeRunning"

    for INFO in "${JOB_INFO[@]}"; do
        # Parse job info
        JOB_ID=$(echo $INFO | awk '{print $1}')
        NAME=$(echo $INFO | awk '{print $2}')
        PARTITION=$(echo $INFO | awk '{print $3}')
        NODE_NAME=$(echo $INFO | awk '{print $4}')
        TIME_RUNNING=$(echo $INFO | awk '{print $5}')

        # Output the collected information
        printf "%-8s\t%-18s\t%-12s\t%-16s\t%-12s\t%s\n" "$JOB_ID" "$NAME" "$PARTITION" "$NODE_NAME" "$TIME_RUNNING"

        file=$(find $1 -type f -name "*$JOB_ID*.out")
        # Check if the file was found
        if ! [[ -z "$file" ]]; then
            if [[ ! -z "$2" && $INFO == *"train"* ]]; then
                stream=$(cat "$file" | tail -n 300)
                epoch_number=$(echo $stream | tail -n 10 | grep -oP 'Epoch \K\d{1,5}' | tail -n 1)
                percentage=$(echo $stream | tail -n 10 | grep -oP 'Epoch \d{1,5}:  \K\d{1,3}+%'| tail -n 1)
                dice_score=$(echo $stream | grep -oP 'Dice score: \K\d+\.\d+'| tail -n 1 | cut -c 1-10)
                whole_image_dice_score=$(echo $stream | grep -oP 'Whole image dice score overall: \K\d+\.\d+'| tail -n 1 | cut -c 1-10)

                echo -e "├─ Training Info : Epoch $epoch_number - $percentage | Dice P $dice_score - I $whole_image_dice_score"
            fi
            
            line1=$(tail -n 1 "$file" | tr '\r' '\n' | tail -n 1)
            echo -e "└─\e[32m $line1 \e[0m"
        fi
    done
}

# Function to display the last 5 completed jobs
display_recent_jobs() {
    echo -e "\e[44m\e[97m Fetching stats for the last $1 run jobs... \e[0m"        
    # Fetch and format the last 5 completed jobs
    printf "%s\t%-16s\t%s\t%s\t%-12s\t%s\n" "JobID" "JobName" "Partition" "Node" "Elapsed" "Start"
    sacct -X -u $user --format=JobID,JobName%20,Partition,NodeList,Elapsed,State,Start -S $(date --date='7 days ago' +%Y-%m-%d) \
    --noheader | tac | head -n $1 | awk '{
        cmd="date -d \""$7"\" \"+%m/%d %H:%M\""; 
        cmd | getline formatted_date; 
        close(cmd);
        color="97"; # Default to white
        if ($6 == "FAILED") color="31"; # Red for failed
        else if ($6 == "COMPLETED") color="32"; # Green for completed
        else if ($6 == "CANCELLED") color="90"; # Dark Gray for cancelled
        else if ($6 == "PENDING") color="33"; # Yellow for pending
        else if ($6 == "OUT_OF_MEMORY") color="41"; # Background red for out of memory
        else if ($6 == "RUNNING") color="42"; # Background green for running
        else if ($6 == "TIMEOUT") color="47"; # Background dark gray for timeout
        else color="35"; # Magenta for other cases
        printf "\033[1;"color"m%s\033[0m\t%-16s\t%s\t%s\t%-12s\t%s\n", $1, $2, $3, $4, $5, formatted_date
    }'
    echo -e "Legend: \e[31mFAILED\e[0m, \e[32mCOMPLETED\e[0m, \e[90mCANCELLED\e[0m, \e[33mPENDING\e[0m, \e[41mOUT_OF_MEMORY\e[0m, \e[42mRUNNING\e[0m, \e[47mTIMEOUT\e[0m, \e[35mOTHER\e[0m"
}

display_job_links() {
    echo -e "\e[41m\e[97m Generating Sherlock GUI links for running jobs... \e[0m"
    printf "%-8s\t%-16s\n" "JobID" "Link"
    if [ -z "${JOB_INFO[*]}" ]; then
        echo "No running jobs found."
        return
    fi

    for INFO in "${JOB_INFO[@]}"; do
        # Parse job info
        JOB_ID=$(echo $INFO | awk '{print $1}')
        NODE_NAME=$(echo $INFO | awk '{print $4}')
        
        base_url="http://sherlockkpi.ainet.hcvpc.io:3000/d/8OWSMSq4k/job-metrics?orgId=1&from=now-30m&to=now&var-cluster=sherlock&var-host="
        LINK="${base_url}${NODE_NAME}&var-job_id=${JOB_ID}&refresh=5s"
        
        # Output the collected information
        printf "%-8s\t%-16s\n" "$JOB_ID" "$LINK"
    done
}

user=$1

# Call the functions
display_job_stats "$3" "$4"
echo ''
display_recent_jobs "$2"
echo ''
display_job_links

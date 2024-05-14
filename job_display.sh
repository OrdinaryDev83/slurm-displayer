#!/bin/bash

# Define a function to fetch and display JobID, AveCPUFreq, Node Name, Partition, and Time Running    
display_job_stats() {
    # Use squeue to get list of running jobs' IDs, Partition, Node Names, and Time Running
    echo -e "\e[42m\e[97m Fetching stats for running jobs... \e[0m"
    readarray -t JOB_INFO <<< "$(squeue -u $1 -t RUNNING --noheader --format='%i %18j %P %N %M %G')" 

    # Check if there are no running jobs
    if [ -z "${JOB_INFO[*]}" ]; then
        echo "No running jobs found."
        return
    fi

    # Header
    printf "%-8s\t%-18s\t%-12s\t%-16s\t%-12s\t%s\n" "JobID" "Name" "Partition" "NodeName" "TimeRunning"

    for INFO in "${JOB_INFO[@]}"; do
        # Parse job info
        read -a JOB <<< "$INFO"
        JOB_ID=${JOB[0]}
        NAME=${JOB[1]}
        PARTITION=${JOB[2]}
        NODE_NAME=${JOB[3]}
        TIME_RUNNING=${JOB[4]}

        # Output the collected information
        printf "%-8s\t%-18s\t%-12s\t%-16s\t%-12s\t%s\n" "$JOB_ID" "$NAME" "$PARTITION" "$NODE_NAME" "$TIME_RUNNING"

        # Check if the file was already found and stored in the dictionary
        if [[ ! -z ${FILE_DICT[$JOB_ID]} ]]; then
            file=${FILE_DICT[$JOB_ID]}
        else
            file=$(find $3 -type f -name "*$JOB_ID*.out" -print -quit)
            if [[ ! -z "$file" ]]; then
                FILE_DICT[$JOB_ID]=$file
            fi
        fi

        # Check if the file was found
        if [[ -n "$file" ]]; then
            if [[ -n "$4" && $INFO == *"train"* ]]; then
                update_variables "$file" "$JOB_ID" "train"
                epoch=${VARIABLES["$JOB_ID,epoch_number"]}
                percentage=${VARIABLES["$JOB_ID,percentage"]}
                dice_score=${VARIABLES["$JOB_ID,dice_score"]}
                whole_image_dice_score=${VARIABLES["$JOB_ID,whole_image_dice_score"]}
                version_number=${VARIABLES["$JOB_ID,version_number"]}
                echo -e "├─ Training Info : Epoch ${epoch} - ${percentage}% | Dice P ${dice_score/^/.} - I ${whole_image_dice_score/^/.} | Version ${version_number}"
            elif [[ -n "$4" && $INFO == *"test"* ]]; then
                update_variables "$file" "$JOB_ID" "test"
                percentage=${VARIABLES["$JOB_ID,percentage"]}
                version_number=${VARIABLES["$JOB_ID,version_number"]}
                echo -e "├─ Testing Info : Epoch ${percentage}% | Version ${version_number}"
            fi

            line1=$(tail -n 1 "$file" | tr '\r' '\n' | tail -n 1)
            echo -e "└─\e[32m $line1 \e[0m"
        fi
    done
}

# Function to update the variables from the last line of the log file
update_variables() {
    local file=$1
    local jobid=$2
    local type=$3

    epoch_number=${VARIABLES[${jobid},epoch_number]}
    percentage=${VARIABLES[${jobid},percentage]}
    dice_score=${VARIABLES[${jobid},dice_score]}
    whole_image_dice_score=${VARIABLES[${jobid},whole_image_dice_score]}
    version_number=${VARIABLES[${jobid},version_number]}

    size=1
    if [[ -z "$epoch_number" || -z "$percentage" || -z "$version_number" ]]; then
        size=10
    elif [[ -z "$dice_score" || -z "$whole_image_dice_score" ]]; then
        size=300
    fi
    stream=$(tail -n $size "$file")
    
    if [[ $type == "train" ]]; then
        epoch_number=$(echo "$stream" | grep -oP 'Epoch \K\d{1,5}' | tail -n 1)
        percentage=$(echo "$stream" | grep -oP '\K\d{1,3}+%'| tail -n 1)
        dice_score=$(echo "$stream" | grep -oP 'Dice score: \K\d+\.\d+'| tail -n 1 | cut -c 1-10)
        whole_image_dice_score=$(echo "$stream" | grep -oP 'Whole image dice score overall: \K\d+\.\d+'| tail -n 1 | cut -c 1-10)
        version_number=$(echo "$stream" | grep -oP ', v_num=\K\d{1,3}' | tail -n 1)
    elif [[ $type == "test" ]]; then
        percentage=$(echo "$stream" | grep -oP '\K\d{1,3}+%'| tail -n 1)
        version_number=$(echo "$stream" | grep -oP ', v_num=\K\d{1,3}' | tail -n 1)
    fi

    percentage=${percentage/\%/}
    dice_score=${dice_score/\./^}
    whole_image_dice_score=${whole_image_dice_score/\./^}
    VARIABLES["${jobid},epoch_number"]="${epoch_number}"
    VARIABLES["${jobid},percentage"]="${percentage}"
    VARIABLES["${jobid},dice_score"]="${dice_score}"
    VARIABLES["${jobid},whole_image_dice_score"]="${whole_image_dice_score}"
    VARIABLES["${jobid},version_number"]="${version_number}"
}

# Function to display the last 5 completed jobs
display_recent_jobs() {
    echo -e "\e[44m\e[97m Fetching stats for the last $2 run jobs... \e[0m"        
    # Fetch and format the last 5 completed jobs
    printf "%s\t%-16s\t%s\t%s\t%-12s\t%s\n" "JobID" "JobName" "Partition" "Node" "Elapsed" "Start"
    sacct -X -u $1 --format=JobID,JobName%20,Partition,NodeList,Elapsed,State,Start -S $(date --date='7 days ago' +%Y-%m-%d) \
    --noheader | tac | head -n $2 | awk '{
        if ($7 == "PENDING") {
            formatted_date = "PENDING";
        } else if ($7 == "CANCELLED+") {
            formatted_date = "LEFT QUEUE";
        } else {
            cmd="date -d \""$7"\" \"+%m/%d %H:%M\""; 
            cmd | getline formatted_date; 
            close(cmd);
        }
        color="35"; # Default to white
        if ($6 == "FAILED") color="31"; # Red for failed
        else if ($6 == "COMPLETED") color="32"; # Green for completed
        else if ($6 == "CANCELLED+" || $7 == "CANCELLED+") color="90"; # Dark Gray for cancelled
        else if ($6 == "PENDING"|| $7 == "PENDING") color="33"; # Yellow for pending
        else if ($6 == "OUT_OF_MEMORY") color="41"; # Background red for out of memory
        else if ($6 == "RUNNING") color="42"; # Background green for running
        else if ($6 == "TIMEOUT") color="47"; # Background dark gray for timeout
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
        read -a JOB <<< "$INFO"
        JOB_ID=${JOB[0]}
        NODE_NAME=${JOB[3]}
        
        base_url="http://sherlockkpi.ainet.hcvpc.io:3000/d/8OWSMSq4k/job-metrics?orgId=1&from=now-30m&to=now&var-cluster=sherlock&var-host="
        LINK="${base_url}${NODE_NAME}&var-job_id=${JOB_ID}&refresh=5s"
        
        # Output the collected information
        printf "%-8s\t%-16s\n" "$JOB_ID" "$LINK"
    done
}
export -f display_job_stats
export -f display_recent_jobs
export -f display_job_links
export -f update_variables

# watch instead
loop(){
    display_job_stats $1 $2 $3 $4
    echo ''
    display_recent_jobs $1 $2 $3 $4
    echo ''
    display_job_links $1 $2 $3 $4
    sleep 2
}
export -f loop

loop $1 $2 $3 $4
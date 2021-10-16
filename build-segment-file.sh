#!/bin/bash
# This script is for creating segment files for mpv-segment-linking
# Available at: https://github.com/CogentRedTester/mpv-segment-linking
# Segment File version: v0.1

output_file=".segment-linking"
declare -a files=()

while (( "$#" > 0 ))
do
    if [[ "$1" == "-o" ]]
    then
        shift
        output_file=$1
        shift
        break
    fi
    
    files+=("$1")
    shift
done

echo "# mpv-segment-linking v0.1" > $output_file
echo "" >> $output_file

for file in "${files[@]}"
do
    out=$(mkvinfo "$file")

    # if mkvinfo could not scan the file then skip
    if [ $? -ne 0 ]
    then
        continue
    fi

    echo "$file" >> $output_file

    regex="Segment UID: ([0-9a-zA-Z ]+)"
    if [[ $out =~ $regex ]]
    then
        echo "UID=${BASH_REMATCH[1]}" >> $output_file
    fi

    regex="Previous segment UID: ([0-9a-zA-Z ]+)"
    if [[ $out =~ $regex ]]
    then
        echo "PREV=${BASH_REMATCH[1]}" >> $output_file
    fi

    regex="Next segment UID: ([0-9a-zA-Z ]+)"
    if [[ $out =~ $regex ]]
    then
        echo "NEXT=${BASH_REMATCH[1]}" >> $output_file
    fi

    echo "" >> $output_file
done
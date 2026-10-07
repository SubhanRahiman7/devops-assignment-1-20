#!/bin/bash
# System Information Script
# Prints date, hostname, user, disk usage and running processes,
# then stores the process list in a file inside a user-named directory.

current_date=$(date)
host_name=$(hostname)
user_name=$(whoami)

echo "Current date : $current_date"
echo "Hostname     : $host_name"
echo "Username     : $user_name"

echo
echo "===== Disk usage ====="
df -h

echo
echo "===== Running processes (first 10 lines) ====="
ps aux | head -n 10

echo
read -p "Enter directory name to create: " dir_name
read -p "Enter file name to create: " file_name

mkdir -p "$dir_name"
touch "$dir_name/$file_name"
echo "Created directory '$dir_name' and file '$dir_name/$file_name'"

# store running processes in the file using > redirection
ps aux > "$dir_name/$file_name"
echo "Running processes saved to $dir_name/$file_name"

echo
echo "===== First 5 lines of $dir_name/$file_name ====="
head -n 5 "$dir_name/$file_name"
echo "Total lines saved: $(wc -l < "$dir_name/$file_name")"

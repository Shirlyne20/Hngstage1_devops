#!/bin/bash

# Log file
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure log directory and file exist
mkdir -p /var/log /var/secure
touch "$LOG_FILE"
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Check for input file argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input-file>"
    exit 1
fi

INPUT_FILE="$1"

# Function to generate a random password
generate_password() {
    echo "$(openssl rand -base64 12)"
}

# Read the input file line by line
while IFS=';' read -r username groups; do
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Create personal group
    if ! getent group "$username" >/dev/null; then
        groupadd "$username"
        echo "Group $username created." | tee -a "$LOG_FILE"
    else
        echo "Group $username already exists." | tee -a "$LOG_FILE"
    fi

    # Create user with personal group
    if ! id "$username" >/dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        echo "User $username created with home directory." | tee -a "$LOG_FILE"
    else
        echo "User $username already exists." | tee -a "$LOG_FILE"
    fi

    # Add user to additional groups
    if [ -n "$groups" ]; then
        IFS=',' read -ra ADDR <<< "$groups"
        for group in "${ADDR[@]}"; do
            group=$(echo "$group" | xargs)
            if ! getent group "$group" >/dev/null; then
                groupadd "$group"
                echo "Group $group created." | tee -a "$LOG_FILE"
            fi
            usermod -aG "$group" "$username"
            echo "User $username added to group $group." | tee -a "$LOG_FILE"
        done
    fi

    # Generate and store password
    password=$(generate_password)
    echo "$username,$password" >> "$PASSWORD_FILE"
    echo "$username's password generated and stored securely." | tee -a "$LOG_FILE"
done < "$INPUT_FILE"

#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install ZSH if not already installed
apt-get update
apt-get install -y zsh

# Set ZSH as default shell for all users
chsh -s $(which zsh)

# Create the central log file
CENTRAL_LOG="/var/log/command_history.log"
touch $CENTRAL_LOG
chmod 644 $CENTRAL_LOG

# Function to add to all users' .zshrc files
add_to_zshrc() {
  local zshrc_file="$1/.zshrc"
  
  # Create .zshrc if it doesn't exist
  touch "$zshrc_file"
  
  # Add the logging function to .zshrc
  cat << 'EOF' >> "$zshrc_file"

# Function to log commands
log_command() {
  local log_file="/var/log/command_history.log"
  local cmd=$(fc -ln -1)
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $USER: $cmd" | sudo tee -a $log_file >/dev/null
}

# Add the log_command function to the preexec hook
autoload -U add-zsh-hook
add-zsh-hook preexec log_command
EOF
}

# Add the logging function to all existing users' .zshrc files
for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    add_to_zshrc "$user_home"
    chown $(stat -c '%U:%G' "$user_home") "$user_home/.zshrc"
  fi
done

# Add the logging function to root's .zshrc
add_to_zshrc "/root"

# Set up log rotation
cat << EOF > /etc/logrotate.d/command_history
$CENTRAL_LOG {
    rotate 7
    daily
    compress
    missingok
    notifempty
}
EOF

echo "Setup complete. Please log out and log back in for changes to take effect."
echo "All user commands will now be logged to $CENTRAL_LOG"

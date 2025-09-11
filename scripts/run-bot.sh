#!/bin/bash

# Load the RVM environment
source "/etc/profile.d/rvm.sh"

git pull origin main
# Run your Ruby script
/usr/local/rvm/rubies/ruby-3.3.0/bin/ruby /root/awesome-crypto-tutorial.github.io/scripts/social-media-bot.rb
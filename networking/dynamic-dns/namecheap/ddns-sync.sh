#!/bin/bash

# This script synchronizes the public IPv4 address of the machine with the DNS records of a specified domain using
# Namecheap's Dynamic DNS API. It is designed to be run periodically (e.g., via cron) to ensure that the domain always
# points to the correct IP address, even if it changes due to dynamic IP assignment by the ISP.

# ANSI color codes for terminal output.
nc='\033[0m'
cred="\033[0;31m"
cblue="\033[0;34m"
cgreen="\033[0;32m"

# Status icons for visual feedback in terminal.
icon_step="${cblue}➜${nc}"
icon_fail="${cred}✖"
icon_done="${cgreen}✔"

# System dependencies required for network operations and DNS lookups.
required_tools=("curl" "dig")

# Check for required tools before proceeding with the script.
for tool in "${required_tools[@]}"; do
	if ! command -v "$tool" &>/dev/null; then
		# Print error message with installation hint for the missing tool.
		printf "${icon_fail} It looks like '%s' is not installed on your system\n" "$tool"
		exit 1
	fi
done

# Attempt to load environment variables from local .env file.
if [ -f .env ]; then
	set -a
	# shellcheck source=/dev/null
	source .env
	set +a
else
	printf "%b Missing '.env' file\n" "${icon_fail}"
	exit 1
fi

# Validate that critical credentials and target domain are present in the environment variables.
if [[ -z "$DOMAIN" || -z "$DDNS_PASSWORD" ]]; then
	printf "%b DOMAIN or DDNS_PASSWORD not set in '.env' file\n" "${icon_fail}"
	exit 1
fi

# Fetch the machine's current public IPv4 address using Amazon's checkip service
# A 10-second timeout is set to prevent the script from hanging on network issues
local_ip=$(curl -s --max-time 10 http://checkip.amazonaws.com)

# Validate IP format using Regex to ensure a successful response was received.
if [[ ! "$local_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf "%b Invalid Public IP.\n" "${icon_fail}"
	exit 1
fi

# Display the detected public IP address to the user.
printf "\n"
printf "%b Public: %s%b\n\n" "${icon_step}" "$local_ip" "${nc}"

# Update Loop, if records are defined, we iterate through them. Otherwise, we just process the root (@).
for record in ${RECORDS:-"@"}; do
	# Clean any accidental whitespace or commas from the record variable to ensure proper formatting for API calls.
	record=$(echo "$record" | tr -d ',[:space:]')

	# Skip empty records after cleaning, which can occur if there were extra spaces or commas in the input.
	[ -z "$record" ] && continue

	# Handles Namecheap's logic: root domain (@) must be passed as an empty string for FQDN building.
	sub="${record//@/}"
	full_domain="${sub}${sub:+.}${DOMAIN}"

	# Display the domain being processed to the user for clarity.
	printf "%b Record: %s\n" "${icon_step}" "${full_domain}"

	# Query Google's Public DNS (@8.8.8.8) directly to avoid local ISP cachingissues and get the current IP associated with the domain.
	current_dns=$(dig +short "@8.8.8.8" "$full_domain")

	# No action needed if DNS record matches current IP, otherwise attempt to update via Namecheap API.
	if [ "$current_dns" == "$local_ip" ]; then
		printf "%b Already points to %s\n" "${icon_done}" "$local_ip"
	else
		# Trigger Namecheap DDNS API update
		# Using the original 'record' variable ensures '@' is passed correctly if it was defined.
		update=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${sub:-@}&domain=${DOMAIN}&password=${DDNS_PASSWORD}")

		# Check for success. Otherwise, extract and display the specific
		# error message returned by the API for troubleshooting.
		if [[ "$update" == *"<ErrCount>0</ErrCount>"* ]]; then
			printf "%b Updated to %s\n" "${icon_done}" "$local_ip"
		else
			# Extract the specific error message from the XML using sed.
			api_error=$(echo "$update" | sed -n 's/.*<Err1>\(.*\)<\/Err1>.*/\1/p')

			# If for some reason we can't parse the error, show a generic one.
			error_msg="${api_error:-"Unknown error occurred"}"

			# Display the error message to the user for troubleshooting.
			printf "%b %s\n" "${icon_fail}" "${error_msg}"
		fi
	fi

	# Add a newline for better readability between records if multiple are being processed.
	printf "\n"

done

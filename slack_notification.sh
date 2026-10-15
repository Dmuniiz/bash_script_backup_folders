#!/bin/bash
SLACK_WEBHOOK_URL=

# Function: send_slack_message
# Arguments: $1 = Message text, $2 = Status ("success", "error", or "info")
send_slack_message() {
    local message="$1"
    local color="#36a64f"

    # JSON Payload with Slack Attachment Formatting
    local payload=$(cat <<EOF
{
    "attachments": [
        {
        "color": "$color",
        "text": "$message",
        "ts": $(date +%s)
        }
    ]
}
EOF
)

    # Send POST request to Slack
    curl -s -X POST -H 'Content-type: application/json' \
        --data "$payload" "$SLACK_WEBHOOK_URL" > /dev/null
}


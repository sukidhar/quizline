#!/bin/sh
log_info() {
    # https://www.howtogeek.com/410442/how-to-display-the-date-and-time-in-the-linux-terminal-and-use-it-in-bash-scripts/
    # printf '%s %s\n' "$(date -u +"%Y-%m-%d %H:%M:%S:%3N%z") INFO  Wrapper: $1"  # Display UTC time
    printf '%s %s\n' "$(date +"%Y-%m-%d %H:%M:%S:%3N%z") INFO  Wrapper: $1" # Display local time (PST/PDT)
    return
}

log_info "Checking to see if Neo4j has started..."
wget --quiet --tries=10 --waitretry=10 -O /dev/null http://${DB_HOST}:${DB_PORT}
log_info "Neo4j has started 🤓"


#!/bin/bash

LOGFILE="${LOGFILE:-/var/log/monitoring.log}"
PROCESS="${PROCESS:-test}"
URL="${MONITOR_URL:-https://test.com/monitoring/test/api}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
EXIT_OK=0
EXIT_SERVICE_DOWN=1
EXIT_HTTP_FAILED=2
EXIT_TELEGRAM_FAILED=3

log_message() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp - $1" >> "$LOGFILE"
}

send_telegram_alert() {
    local message="$1"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 0
    fi

    local payload
    payload=$(printf '{"chat_id":"%s","text":"%s","disable_notification":false}' "$TELEGRAM_CHAT_ID" "$message")

    if ! curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null 2>&1; then
        log_message "Telegram alert failed: $message"
        return 1
    fi

    return 0
}

main() {
    local status
    status=$(systemctl is-active "$PROCESS" 2>/dev/null || echo "unknown")

    if [ "$status" != "active" ]; then
        log_message "$PROCESS not running (status: $status), restarting..."

        if systemctl restart "$PROCESS" >/dev/null 2>&1; then
            log_message "$PROCESS restarted successfully"
            send_telegram_alert "$PROCESS restarted successfully after becoming inactive" || true
            exit $EXIT_SERVICE_DOWN
        fi

        log_message "$PROCESS restart failed"
        send_telegram_alert "$PROCESS restart failed" || exit $EXIT_TELEGRAM_FAILED
        exit $EXIT_SERVICE_DOWN
    fi

    local http_status
    http_status=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$URL" || echo "000")

    if [ "$http_status" = "200" ]; then
        log_message "$PROCESS is running and HTTP check passed (HTTP $http_status)"
        exit $EXIT_OK
    fi

    log_message "$PROCESS is running but HTTP check failed with code $http_status"
    if ! send_telegram_alert "$PROCESS is running but HTTP check failed with HTTP code $http_status"; then
        exit $EXIT_TELEGRAM_FAILED
    fi

    exit $EXIT_HTTP_FAILED
}

main "$@"

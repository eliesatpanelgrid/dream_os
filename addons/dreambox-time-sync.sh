#!/usr/bin/env bash
# Dreambox Time & NTP Management Tool with Persistence Setup

SCRIPT_PATH="$(readlink -f "$0")"
SYNC_CMD="/usr/bin/dreambox-ntp-sync"

get_local_time() {
    date "+%Y-%m-%d %H:%M:%S"
}

probe_ntp() {
    echo -e "\n[+] Probing NTP Server..."
    NTP_TIMESTAMP=""
    if [ -x "$SYNC_CMD" ]; then
        OUTPUT=$($SYNC_CMD --probe 2>/dev/null)
        NTP_TIMESTAMP=$(echo "$OUTPUT" | grep "NTP_TIMESTAMP=" | cut -d'=' -f2)
    fi

    LOCAL_EPOCH=$(date +%s)

    if [ -n "$NTP_TIMESTAMP" ]; then
        NTP_EPOCH=${NTP_TIMESTAMP%.*}
        NTP_FORMATTED=$(date -d "@$NTP_EPOCH" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$NTP_EPOCH" "+%Y-%m-%d %H:%M:%S")
        DIFF=$((NTP_EPOCH - LOCAL_EPOCH))

        echo "Local Time:    $(get_local_time)"
        echo "Internet Time: $NTP_FORMATTED"
        echo "Difference:    ${DIFF} seconds"
    else
        echo "Local Time:    $(get_local_time)"
        echo "Internet Time: Unavailable (Check connection or binary)"
    fi
}

sync_ntp() {
    echo -e "\n[+] Synchronizing time with NTP..."
    if [ -x "$SYNC_CMD" ]; then
        $SYNC_CMD --manual
    else
        ntpdate -u pool.ntp.org || sntp -s pool.ntp.org
    fi

    if [ $? -eq 0 ]; then
        echo "[✓] Synchronization successful!"
        echo "New Local Time: $(get_local_time)"
    else
        echo "[✗] Synchronization failed."
    fi
}

set_manual_time() {
    echo -e "\n--- Set Date and Time Manually ---"
    read -p "Year (YYYY): " YYYY
    read -p "Month (MM): " MM
    read -p "Day (DD): " DD
    read -p "Hour (HH, 24h): " HH
    read -p "Minute (MM): " MIN
    read -p "Second (SS): " SS

    if ! date -d "$YYYY-$MM-$DD $HH:$MIN:$SS" >/dev/null 2>&1; then
        echo "[✗] Invalid date/time format entered."
        return 1
    fi

    echo "[+] Applying new time..."
    if [ -x "$SYNC_CMD" ]; then
        $SYNC_CMD --set-time "$YYYY" "$MM" "$DD" "$HH" "$MIN" "$SS"
    else
        date -s "$YYYY-$MM-$DD $HH:$MIN:$SS"
    fi

    if [ $? -eq 0 ]; then
        echo "[✓] System clock updated successfully!"
        echo "Current Time: $(get_local_time)"
    else
        echo "[✗] Failed to set system clock."
    fi
}

toggle_boot_persistence() {
    echo -e "\n--- Boot Persistence Management ---"
    
    # Check if cron service is active
    if ! systemctl is-active --quiet cron && ! systemctl is-active --quiet crond; then
        echo "[!] Enabling and starting cron service..."
        systemctl enable --now cron 2>/dev/null || systemctl enable --now crond 2>/dev/null
    fi

    # Check existing cron entry
    CRON_EXISTS=$(crontab -l 2>/dev/null | grep -F "$SYNC_CMD")

    if [ -n "$CRON_EXISTS" ]; then
        echo "[*] Auto-sync on boot is currently ENABLED."
        read -p "Do you want to DISABLE auto-sync on boot? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            (crontab -l 2>/dev/null | grep -v -F "$SYNC_CMD") | crontab -
            echo "[✓] Boot persistence removed successfully."
        fi
    else
        echo "[*] Auto-sync on boot is currently DISABLED."
        read -p "Do you want to ENABLE auto-sync 30s after every boot? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            # Write robust boot entry to root crontab
            (crontab -l 2>/dev/null; echo "@reboot sleep 30 && $SYNC_CMD --manual >/dev/null 2>&1") | crontab -
            echo "[✓] Boot persistence configured! Time will sync automatically after reboot."
        fi
    fi
}

purge_plugin() {
    read -p "Are you sure you want to purge dreambox-ntp-sync and restart Enigma2? (y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        # Clean up cron entry first
        (crontab -l 2>/dev/null | grep -v -F "$SYNC_CMD") | crontab -
        
        echo "[+] Purging plugin via dpkg..."
        DREAMBOX_NTP_UI_REMOVE=1 /usr/bin/dpkg --purge dreambox-ntp-sync
        
        if [ $? -eq 0 ]; then
            echo "[✓] Plugin removed. Restarting Enigma2 service..."
            systemctl restart enigma2.service
        else
            echo "[✗] Removal failed. Please run manually."
        fi
    fi
}

show_menu() {
    while true; do
        echo -e "\n======================================"
        echo "     Dreambox NTP Time Manager"
        echo "======================================"
        echo "1) Refresh / Probe Internet Time"
        echo "2) Synchronize with NTP Now"
        echo "3) Set Date/Time Manually"
        echo "4) Enable / Disable Auto-Sync on Boot"
        echo "5) Remove Package & Restart Enigma2"
        echo "6) Exit"
        read -p "Select an option [1-6]: " CHOICE

        case $CHOICE in
            1) probe_ntp ;;
            2) sync_ntp ;;
            3) set_manual_time ;;
            4) toggle_boot_persistence ;;
            5) purge_plugin ;;
            6) echo "Exiting."; exit 0 ;;
            *) echo "Invalid selection." ;;
        esac
    done
}

show_menu
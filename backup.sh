#!/bin/bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

DOCUMENTS_FOLDER=""
DESKTOP_FOLDER=""

RCLONE_CONF="/.config/rclone/rclone.conf"

ROOT_DRIVE="gdrive:Backup_Nuvem"

DATE_DIR=$(date +%Y-%m-%d)

DRIVE_DESTINO="gdrive:Backup_Nuvem/$DATE_DIR"

TMP_DIR="/tmp/backup_gdrive"
LOG_FILE="$HOME/backup_nuvem.log"

LIMIT_STORAGE_DAYS=30
START_TIME=$(date +%s)

source slack_notification.sh
touch "$LOG_FILE" 2>/dev/null
mkdir -p "$TMP_DIR"

#----------------------------------------------------------------------------------------------

#HANDLING ERRORS
on_error(){
    local line_number=$1
    echo "$TIMESTAMP : Error occurred at line $line_number" >> "$LOG_FILE"
    exit 1
}
trap 'on_error $LINENO' ERR
set -e #If any thing fails, the script will exit immediately

#----------------------------------------------------------------------------------------------

echo "$TIMESTAMP --- Initializing compress backup to google ---" >> "$LOG_FILE"

RCLONE_CMD="rclone --config $RCLONE_CONF"

# 1. COMPRESS AND UPLOAD DOCUMENTS
if [ -d "$DOCUMENTS_FOLDER" ]; then
    echo "$TIMESTAMP Compress Documents folder..." >> "$LOG_FILE"
    tar -czf "$TMP_DIR/documents_$DATE_DIR.tar.gz" -C "$(dirname "$DOCUMENTS_FOLDER")" "$(basename "$DOCUMENTS_FOLDER")" 2>> "$LOG_FILE"
    
    echo "$TIMESTAMP Sending compressed documents to Drive" >> "$LOG_FILE"
    $RCLONE_CMD move "$TMP_DIR/documents_$DATE_DIR.tar.gz" "$DRIVE_DESTINO/" >> "$LOG_FILE" 2>&1

    #1 - stdout - output standard - where the programs sends its normal output
    #& - file descriptor - 0 stdin, 1 stdout, 2 stderr

else
    echo "$TIMESTAMP WARNING - Documents Folder not found" >> "$LOG_FILE"
fi

# 2. COMPRESS AND UPLOAD DESKTOP
if [ -d "$DESKTOP_FOLDER" ]; then
    echo "$TIMESTAMP Compress Desktop folder..." >> "$LOG_FILE"
    tar -czf "$TMP_DIR/desktop_$DATE_DIR.tar.gz" -C "$(dirname "$DESKTOP_FOLDER")" "$(basename "$DESKTOP_FOLDER")" 2>> "$LOG_FILE"
    
    echo "$TIMESTAMP Sending compressed desktop to Drive" >> "$LOG_FILE"
    $RCLONE_CMD move "$TMP_DIR/desktop_$DATE_DIR.tar.gz" "$DRIVE_DESTINO/" >> "$LOG_FILE" 2>&1
else
    echo "$TIMESTAMP WARNING - Desktop Folder not found" >> "$LOG_FILE"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
ARCHIVE_SIZE=$(du -sh "$TMP_DIR/documents_$DATE_DIR.tar.gz" 2>/dev/null | cut -f1)
#2 - stderr - output error - where the programs sends its error messages
#> redirects stdout to a file
#/dev/null - virtual file that discard all data written to it

send_slack_message "*Backup completed $HOSTNAME"

# 3. RETENTION (CLEAN OLD BACKUPS)
echo "$TIMESTAMP Checking backups older than $LIMIT_STORAGE_DAYS days..." >> "$LOG_FILE" 

# 1. Delete files older than $LIMIT_STORAGE_DAYS
$RCLONE_CMD delete "$ROOT_DRIVE/" --min-age "${LIMIT_STORAGE_DAYS}d" >> "$LOG_FILE" 2>&1 

# 2. Delete ONLY directories that are empty AND older than $LIMIT_STORAGE_DAYS
#$RCLONE_CMD rmdirs "$ROOT_DRIVE/" --min-age "${LIMIT_STORAGE_DAYS}d" >> "$LOG_FILE" 2>&1

# Google Drive - Trash
$RCLONE_CMD cleanup "$ROOT_DRIVE" >> "$LOG_FILE" 2>&1

send_slack_message "Older backups deleted from $HOSTNAME"

rm -rf "$TMP_DIR"/*
echo "$TIMESTAMP --- Backup completed successfully --- Duration: ${DURATION}s --- Archive Size: ${ARCHIVE_SIZE} ---" >> "$LOG_FILE"
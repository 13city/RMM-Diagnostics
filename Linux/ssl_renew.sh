#!/usr/bin/env bash
#
# ssl_renew.sh
#
# SYNOPSIS
#   Automates renewal of a self-signed certificate OR
#   updates Let’s Encrypt cert using certbot.
#

MODE="$1"        # "selfsigned" or "letsencrypt"
DOMAIN="$2"      # e.g., "myinternaldomain.local" or "domainname.com"
CERT_DIR="/etc/ssl/$DOMAIN"
LOGFILE="/var/log/ssl_renew.log"

echo "=== Starting SSL certificate renewal at $(date) ===" | tee -a "$LOGFILE"

if [ "$MODE" == "selfsigned" ]; then
  echo "Generating self-signed certificate for $DOMAIN..." | tee -a "$LOGFILE"
  mkdir -p "$CERT_DIR"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERT_DIR/$DOMAIN.key" \
    -out "$CERT_DIR/$DOMAIN.crt" \
    -subj "/CN=$DOMAIN/O=MyCompany/C=US" 2>>"$LOGFILE"

  echo "Self-signed certificate created at $CERT_DIR" | tee -a "$LOGFILE"

elif [ "$MODE" == "letsencrypt" ]; then
  echo "Requesting Let’s Encrypt certificate for $DOMAIN..." | tee -a "$LOGFILE"
  # Example usage of certbot in non-interactive mode
  certbot certonly --standalone -d "$DOMAIN" --agree-tos -m "admin@$DOMAIN" -n >>"$LOGFILE" 2>&1
  if [ $? -eq 0 ]; then
    echo "Let’s Encrypt certificate obtained successfully!" | tee -a "$LOGFILE"
  else
    echo "ERROR: Let’s Encrypt certificate request failed. Check logs." | tee -a "$LOGFILE"
    exit 1
  fi
else
  echo "Usage: $0 [selfsigned|letsencrypt] <domain>" | tee -a "$LOGFILE"
  exit 1
fi

echo "=== ssl_renew.sh completed at $(date) ===" | tee -a "$LOGFILE"
exit 0
#!/bin/bash
BOOKING_FILE="/etc/ansible/nste/active_booking.json"
[ ! -f "$BOOKING_FILE" ] && exit 0

BOOKING_END=$(jq -r '.end_epoch' "$BOOKING_FILE")
NOW=$(date +%s)

if [ "$NOW" -gt "$BOOKING_END" ]; then
  BOOKING_USER=$(jq -r '.booking_username' "$BOOKING_FILE")
  BOOKING_ID=$(jq -r '.booking_id' "$BOOKING_FILE")
  BOOKING_EMAIL=$(jq -r '.booking_user_email' "$BOOKING_FILE")

  /opt/ansible-venv/bin/ansible-playbook \
    /etc/ansible/nste/playbooks/delete_temp_user.yaml \
    -i /etc/ansible/nste/hosts.ini \
    --vault-password-file /etc/ansible/nste/.vault_pass \
    -e "booking_username=$BOOKING_USER booking_id=$BOOKING_ID booking_user_email=$BOOKING_EMAIL"

  rm -f "$BOOKING_FILE"
  echo "$(date): Stale account cleaned for $BOOKING_USER ($BOOKING_ID) | Notified: $BOOKING_EMAIL" >> /var/log/nste_access.log
fi
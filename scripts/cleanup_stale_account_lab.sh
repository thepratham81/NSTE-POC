#!/bin/bash
BOOKING_FILE="/etc/ansible/nste/active_booking.json"
[ ! -f "$BOOKING_FILE" ] && exit 0

BOOKING_END=$(jq -r '.end_epoch' "$BOOKING_FILE")
NOW=$(date +%s)

if [ "$NOW" -gt "$BOOKING_END" ]; then
  BOOKING_USER=$(jq -r '.booking_username' "$BOOKING_FILE")
  BOOKING_ID=$(jq -r '.booking_id' "$BOOKING_FILE")
  BOOKING_EMAIL=$(jq -r '.booking_user_email' "$BOOKING_FILE")
  LAB_PATH=$(jq -r '.lab_path' "$BOOKING_FILE")

  ANSIBLE="/opt/ansible-venv/bin/ansible-playbook"
  HOSTS="/etc/ansible/nste/hosts.ini"
  VAULT="--vault-password-file /etc/ansible/nste/.vault_pass"
  LOG="/etc/ansible/nste/nste_access.log"

  echo "$(date): [CLEANUP] Booking $BOOKING_ID expired — beginning lab teardown and account revocation for $BOOKING_USER" >> "$LOG"

  # ── Steps 1 & 2: Stop and delete the lab (skipped if lab was never provisioned) ──
  if [ "$LAB_PATH" != "null" ] && [ -n "$LAB_PATH" ]; then

    $ANSIBLE /etc/ansible/nste/playbooks/eve_ng_lab_stop_latest.yaml \
      $VAULT \
      -e "eve_ng_lab_path=$LAB_PATH"

    if [ $? -ne 0 ]; then
      echo "$(date): [ERROR] eve_ng_lab_stop_latest.yaml failed for booking $BOOKING_ID — aborting cleanup" >> "$LOG"
      exit 1
    fi
    echo "$(date): [OK] Lab nodes stopped for booking $BOOKING_ID" >> "$LOG"

    $ANSIBLE /etc/ansible/nste/playbooks/eve_ng_lab_delete_latest.yaml \
      $VAULT \
      -e "eve_ng_lab_path=$LAB_PATH"

    if [ $? -ne 0 ]; then
      echo "$(date): [ERROR] eve_ng_lab_delete_latest.yaml failed for booking $BOOKING_ID — aborting cleanup" >> "$LOG"
      exit 1
    fi
    echo "$(date): [OK] Lab deleted for booking $BOOKING_ID" >> "$LOG"

  else
    echo "$(date): [SKIP] lab_path is null — lab was never provisioned for booking $BOOKING_ID, skipping lab teardown" >> "$LOG"
  fi

  # ── Step 3: Remove the temporary JIT account and notify user ─────────────
  $ANSIBLE /etc/ansible/nste/playbooks/delete_temp_user.yaml \
    -i "$HOSTS" \
    $VAULT \
    -e "booking_username=$BOOKING_USER booking_id=$BOOKING_ID booking_user_email=$BOOKING_EMAIL"

  if [ $? -ne 0 ]; then
    echo "$(date): [ERROR] delete_temp_user.yaml failed for $BOOKING_USER ($BOOKING_ID)" >> "$LOG"
    exit 1
  fi
  echo "$(date): [OK] JIT account removed and revocation email sent for $BOOKING_USER ($BOOKING_ID) | Notified: $BOOKING_EMAIL" >> "$LOG"

  rm -f "$BOOKING_FILE"
fi
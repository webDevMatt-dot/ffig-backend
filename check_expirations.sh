#!/usr/bin/env bash
# check_expirations.sh
# This script runs the Django management command to check membership expirations and send reminders.
# It can be used as the start command for a Render Cron Job.

# Exit on error
set -o errexit

echo "🔄 Running Membership Expiration Reminder checks..."
python manage.py send_expiration_reminders

echo "✅ Expiration check finished successfully."

#!/usr/bin/env bash
# Exit on error
set -o errexit

# Run Migrations (Safe to run on start if DB allows connections)
python manage.py migrate

# Create Superuser if configured (Custom script)
if [ -f "create_superuser.py" ]; then
    python create_superuser.py
fi

# Start Gunicorn
gunicorn ffig_backend.wsgi:application

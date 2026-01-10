#!/usr/bin/env bash
# Exit on error
set -o errexit

# Install dependencies
pip install -r requirements.txt

# Run Migrations (Crucial if using SQLite or for updates)
python manage.py migrate

# Collect Static Files
python manage.py collectstatic --noinput

# Create Superuser if configured (Custom script)
if [ -f "create_superuser.py" ]; then
    python create_superuser.py
fi

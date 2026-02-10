#!/usr/bin/env bash
# Exit on error
set -o errexit

# Debug: Print DB Host (Masked)
echo "🔍 Checking DATABASE_URL..."
if [ -n "$DATABASE_URL" ]; then
    echo "✅ DATABASE_URL is set."
    # Extract host for debugging logs (safe way)
    DB_HOST=$(echo $DATABASE_URL | sed -E 's/.*@([^:]+).*/\1/')
    echo "🔌 Attempting to connect to DB Host: $DB_HOST"
else
    echo "❌ DATABASE_URL is MISSING!"
fi

# Run Migrations (Safe to run on start if DB allows connections)
# Added '|| true' to prevent deployment failure if migrations fail (e.g. temporary DNS issue)
echo "🔄 Running Migrations..."
python manage.py migrate || echo "⚠️ Migration Failed! Continuing startup anyway..."

# Create Superuser if configured (Custom script)
if [ -f "create_superuser.py" ]; then
    python create_superuser.py
fi

# Start Gunicorn
gunicorn ffig_backend.wsgi:application

#!/bin/bash
set -e

# Wait for Postgres to start
echo "Waiting for PostgreSQL to start..."
until pg_isready -q; do
  echo "  Postgres is not ready, sleeping..."
  sleep 1
done

echo "🚀 PostgreSQL is up and running!"

# Create Database
echo "Creating database 'ffig_db'..."
createdb ffig_db || echo "Database 'ffig_db' already exists."

# Create User (if needed) - For local dev, we often just use the 'postgres' superuser or current user
# But let's try to match the .env config requested: postgres / your_password
# NOTE: In local dev, usually 'postgres' user exists or we use the current system user. 
# We'll try to create a 'postgres' user if it doesn't exist, with the password from .env

echo "Creating user 'postgres' if not exists..."
psql -d postgres -c "DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
        CREATE ROLE postgres WITH LOGIN PASSWORD 'your_password' SUPERUSER;
    ELSE
        ALTER ROLE postgres WITH PASSWORD 'your_password';
    END IF;
END
\$\$;"

echo "✅ Database setup complete!"

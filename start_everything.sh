#!/bin/bash

# Setup and Start Backend
echo "============================="
echo "Starting Django Backend..."
echo "============================="

if [ ! -d "venv" ]; then
    echo "Creating python virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate
echo "Installing requirements..."
pip install -r requirements.txt

# Check if using remote Render DB to avoid accidental production migrations on every start
if grep -q "DATABASE_URL" .env 2>/dev/null; then
    echo "⚠️  Remote DB detected in .env! Skipping automatic migrations for safety."
    echo "   (To migrate, manually run: source venv/bin/activate && python manage.py migrate)"
else
    echo "Running local migrations..."
    python manage.py migrate
fi

# Ensure no old backend is running on port 8000
echo "Cleaning up any old background processes on port 8000..."
lsof -ti :8000 | xargs kill -9 2>/dev/null || true

# Start backend server in the background
python manage.py runserver &
BACKEND_PID=$!

# Trap Ctrl+C to kill the backend too
function cleanup() {
    echo "Stopping Backend (PID: $BACKEND_PID)..."
    kill $BACKEND_PID
}
trap cleanup EXIT

echo "============================="
echo "Backend is running!"
echo "Starting Emulators & Flutter app..."
echo "============================="

# Start both emulators in the background/parallel
./start_ios_simulator.sh &
./start_android_emulator.sh &

# Wait for both to be ready (enough for run command)
echo "Waiting for devices to be ready..."
sleep 15

# Run the frontend on ALL devices
echo "Launching lib/main.dart on all devices..."
cd mobile_app && flutter run -d all

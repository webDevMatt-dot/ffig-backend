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
python manage.py runserver 0.0.0.0:8000 &
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

# Start ONLY the Android Emulator in the background
./start_android_emulator.sh &

# Wait for it to be ready
echo "Waiting for Android emulator to be ready..."
sleep 15

# Run the frontend on the Android Emulator
echo "Launching lib/main.dart on Android Emulator..."
cd mobile_app && flutter run -d emulator-5554

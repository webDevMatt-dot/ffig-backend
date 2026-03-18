import os
import django
import requests

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.models import User

# Need an admin user to generate a token
admin_user = User.objects.filter(is_superuser=True).first()
if not admin_user:
    admin_user = User.objects.filter(is_staff=True).first()

if not admin_user:
    print("No admin user found.")
    exit(1)

refresh = RefreshToken.for_user(admin_user)
token = str(refresh.access_token)

# Pick a test user to delete (create a dummy one to avoid destroying real data)
dummy_user = User.objects.create(username="dummy_delete_test", email="dummy@delete.com")
print(f"Created dummy user: {dummy_user.id}")

url = f"http://127.0.0.1:8000/api/admin/users/{dummy_user.id}/"
headers = {
    "Authorization": f"Bearer {token}"
}

print(f"Sending DELETE request to {url}...")
response = requests.delete(url, headers=headers)
print(f"Status Code: {response.status_code}")
print(f"Response Body: {response.text}")

# Clean up if it failed
if User.objects.filter(id=dummy_user.id).exists():
    print("API failed to delete user. Falling back to ORM deletion.")
    dummy_user.delete()

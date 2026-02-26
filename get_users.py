import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from members.models import Profile

def get_users():
    premium_users = Profile.objects.filter(tier='PREMIUM').select_related('user')
    standard_users = Profile.objects.filter(tier='STANDARD').select_related('user')

    print("=== PREMIUM USERS ===")
    if not premium_users.exists():
        print("No premium users found.")
    for p in premium_users:
        print(f"- {p.user.username} (Email: {p.user.email})")

    print("\n=== STANDARD USERS ===")
    if not standard_users.exists():
        print("No standard users found.")
    for p in standard_users:
        print(f"- {p.user.username} (Email: {p.user.email})")

if __name__ == "__main__":
    get_users()

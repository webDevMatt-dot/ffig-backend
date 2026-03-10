import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def cleanup_emails():
    # 1. Rosheen (ID 4) -> old_rosheen_4@femalefoundersinitiative.com
    try:
        u4 = User.objects.get(id=4)
        u4.email = "old_rosheen_4@femalefoundersinitiative.com"
        u4.save()
        print(f"Renamed email for user ID 4 (current username: {u4.username})")
    except User.DoesNotExist:
        print("User ID 4 not found.")

    # 2. Tester2_old (ID 32) -> old_tester_32@femalefoundersinitiative.com
    try:
        u32 = User.objects.get(id=32)
        u32.email = "old_tester_32@femalefoundersinitiative.com"
        u32.save()
        print(f"Renamed email for user ID 32 (current username: {u32.username})")
    except User.DoesNotExist:
        print("User ID 32 not found.")

if __name__ == "__main__":
    cleanup_emails()

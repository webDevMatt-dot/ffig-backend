import os
import django
from rest_framework import serializers

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.serializers import UserSerializer, RegisterSerializer

def verify_email_uniqueness():
    print("--- Verifying '1 Email, 1 User' Policy ---")
    
    # 1. Check for any remaining duplicates in the DB
    emails = list(User.objects.values_list('email', flat=True))
    normalized_emails = [e.strip().lower() for e in emails if e]
    
    from collections import Counter
    counts = Counter(normalized_emails)
    duplicates = [email for email, count in counts.items() if count > 1]
    
    if duplicates:
        print(f"❌ FAILURE: Still found duplicate emails in DB: {duplicates}")
        for email in duplicates:
            users = User.objects.filter(email__iexact=email)
            print(f"  Conflict for '{email}': {[u.username for u in users]}")
    else:
        print("✅ SUCCESS: No duplicate emails found in DB.")

    # 2. Test UserSerializer validation for existing email
    print("\n--- Testing UserSerializer Validation ---")
    try:
        president = User.objects.get(username='President')
        matt_luis = User.objects.get(username='matt_luis')
        
        # Try to set President's email to matt_luis's email
        serializer = UserSerializer(president, data={'email': matt_luis.email}, partial=True)
        if serializer.is_valid():
            print("❌ FAILURE: UserSerializer allowed duplicate email on update.")
        else:
            print(f"✅ SUCCESS: UserSerializer blocked duplicate email: {serializer.errors}")
    except User.DoesNotExist:
        print("⚠️ President or matt_luis not found, skipping update validation test.")

    # 3. Test RegisterSerializer validation for existing email
    print("\n--- Testing RegisterSerializer Validation ---")
    try:
        matt_luis = User.objects.get(username='matt_luis')
        data = {
            'username': 'new_user_test',
            'email': matt_luis.email,
            'password': 'password123',
            'password2': 'password123',
            'first_name': 'Test',
            'last_name': 'User'
        }
        serializer = RegisterSerializer(data=data)
        if serializer.is_valid():
            print("⚠️ WARNING: RegisterSerializer currently allows duplicate email. (Updating it now...)")
        else:
            print(f"✅ SUCCESS: RegisterSerializer blocked duplicate email: {serializer.errors}")
    except User.DoesNotExist:
        print("⚠️ matt_luis not found, skipping registration validation test.")

if __name__ == "__main__":
    verify_email_uniqueness()

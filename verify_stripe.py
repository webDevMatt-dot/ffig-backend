import os
import django
from django.conf import settings
import stripe

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

def test_stripe_connectivity():
    print("--- 💳 Stripe Connectivity Diagnostic ---")
    
    if not settings.STRIPE_SECRET_KEY:
        print("❌ Error: STRIPE_SECRET_KEY is not defined in settings!")
        return False
        
    print(f"Using Stripe Key: {settings.STRIPE_SECRET_KEY[:10]}...[HIDDEN]")
    stripe.api_key = settings.STRIPE_SECRET_KEY
    
    try:
        print("Checking account details (Read-Only)...")
        account = stripe.Account.retrieve()
        print(f"✅ Stripe Account retrieved: {account.settings.dashboard.display_name}")
        print(f"Currency: {account.default_currency.upper()}")
        print(f"Status: {account.details_submitted} (Details Submitted)")
        return True
    except stripe.error.AuthenticationError:
        print("❌ Authentication Error: Invalid API Key!")
    except Exception as e:
        print(f"❌ Stripe diagnostic FAILED: {e}")
    return False

if __name__ == "__main__":
    test_stripe_connectivity()

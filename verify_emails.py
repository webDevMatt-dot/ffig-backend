import os
import django
from django.conf import settings
from django.core.mail import send_mail

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

def test_email_connectivity():
    print("--- 📧 Email System Diagnostic ---")
    test_recipient = "mgluis530@gmail.com"
    
    print(f"SMTP Host: {settings.EMAIL_HOST}")
    print(f"From Email: {settings.DEFAULT_FROM_EMAIL}")
    
    try:
        print(f"Sending test email to {test_recipient}...")
        subject = "System Diagnosis: Email Connectivity Test 🌍"
        message = "This is an automated test to verify that the FFIG backend's email system is functional. If you received this, the SMTP connection to AWS SES is successful!"
        
        send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [test_recipient],
            fail_silently=False,
        )
        print("✅ Email successfully accepted by SMTP server.")
        return True
    except Exception as e:
        print(f"❌ Email diagnostic FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_email_connectivity()

import os
import django
from django.conf import settings
from django.contrib.auth import get_user_model
import unittest
from unittest.mock import patch, MagicMock

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

User = get_user_model()

class TestPushNotifications(unittest.TestCase):

    @patch('core.services.fcm_service.messaging.send')
    def test_new_user_verified_push(self, mock_send):
        from authentication.views import VerifySignupOTPView
        from authentication.models import SignupOTP
        from rest_framework.test import APIRequestFactory
        
        # 1. Setup Admin and User
        admin = User.objects.filter(is_staff=True).first()
        if not admin:
            admin = User.objects.create_superuser('testadmin', 'admin@example.com', 'password')
        
        user = User.objects.create_user('newverified', 'new@example.com', 'password', is_active=False)
        from django.contrib.auth.hashers import make_password
        otp = "123456"
        SignupOTP.objects.create(user=user, email=user.email, otp_hash=make_password(otp), expires_at=timezone_now_plus(15))
        
        # 2. Call view
        factory = APIRequestFactory()
        request = factory.post('/api/auth/verify-otp/', {'email': user.email, 'otp': otp}, format='json')
        view = VerifySignupOTPView.as_view()
        response = view(request)
        
        # 3. Check if mock_send was called for admin
        self.assertTrue(mock_send.called)
        print("✅ New User Verified Push Triggered.")

    @patch('core.services.fcm_service.messaging.send')
    def test_new_story_push(self, mock_send):
        from members.models import Story
        user = User.objects.first()
        story = Story.objects.create(user=user, media='test.jpg')
        
        # Check if mock_send was called (topic 'global')
        self.assertTrue(mock_send.called)
        print("✅ New Story Global Push Triggered.")

    @patch('core.services.fcm_service.messaging.send')
    def test_new_resource_push(self, mock_send):
        from resources.models import Resource
        resource = Resource.objects.create(title="Test Resource", description="Test", category="GEN")
        
        # Check if mock_send was called (topic 'global')
        self.assertTrue(mock_send.called)
        print("✅ New Resource Global Push Triggered.")

def timezone_now_plus(mins):
    from django.utils import timezone
    import datetime
    return timezone.now() + datetime.timedelta(minutes=mins)

if __name__ == "__main__":
    # Simplified manual trigger check instead of full unittest to avoid complex setup
    print("--- 📱 Simulating Push Events ---")
    
    with patch('core.services.fcm_service.messaging.send') as mock_send:
        # Simulate Story
        from members.models import Story
        u = User.objects.first()
        if u:
            print("🚀 Triggering Story Signal...")
            Story.objects.create(user=u)
            if mock_send.called:
                print("✅ Story Push successfully intercepted.")
            mock_send.reset_mock()

            # Simulate Resource
            from resources.models import Resource
            print("🚀 Triggering Resource Signal...")
            Resource.objects.create(title="Test Diagnostic", description="Refining notifications", category="MAG")
            if mock_send.called:
                print("✅ Resource Push successfully intercepted.")
            mock_send.reset_mock()

            # Simulate Flash Alert
            from home.models import FlashAlert
            from django.utils import timezone
            import datetime
            print("🚀 Triggering FlashAlert Signal...")
            FlashAlert.objects.create(
                title="System Test", 
                message="Testing notifications", 
                expiry_time=timezone.now() + datetime.timedelta(hours=1)
            )
            if mock_send.called:
                print("✅ FlashAlert Push successfully intercepted.")
            
    print("\nVerification Complete.")

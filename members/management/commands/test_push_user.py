from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from core.services.fcm_service import send_push_notification

class Command(BaseCommand):
    help = 'Sends a test push notification to a specific user'

    def add_arguments(self, parser):
        parser.add_argument('username', type=str, help='The username of the recipient')

    def handle(self, *args, **options):
        username = options['username']
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f"User '{username}' does not exist."))
            return

        self.stdout.write(f"Attempting to send push to {user.username}...")
        
        self.stdout.write(f"Using FCM Token: {user.profile.fcm_token}")

        # Debug Firebase App
        import firebase_admin
        from firebase_admin import _apps
        self.stdout.write(f"Initialized Apps: {[app.name for app in _apps.values()]}")
        default_app = firebase_admin.get_app()
        self.stdout.write(f"Default App Project: {default_app.project_id}")

        success = send_push_notification(
            user=user,
            title="🛠 SERVER TEST",
            body="Is it working now?",
            data={"type": "test", "test_id": "123"}
        )

        if success:
            self.stdout.write(self.style.SUCCESS(f"Successfully sent push to {user.username}!"))
        else:
            self.stdout.write(self.style.ERROR(f"Failed to send push to {user.username}. Check logs for errors."))

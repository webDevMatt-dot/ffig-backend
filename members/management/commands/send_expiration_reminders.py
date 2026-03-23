from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from members.models import Profile
from core.services.email_service import send_membership_reminder_email
from core.services.fcm_service import send_push_notification

class Command(BaseCommand):
    help = 'Sends reminders to users whose membership expires in exactly 90, 30, or 7 days.'

    def handle(self, *args, **kwargs):
        today = timezone.now().date()
        target_days = [90, 30, 7]
        
        for days in target_days:
            target_date = today + timedelta(days=days)
            
            expiring_profiles = Profile.objects.filter(subscription_expiry__date=target_date)
            
            if not expiring_profiles.exists():
                self.stdout.write(self.style.SUCCESS(f"No profiles expiring in exactly {days} days."))
                continue
                
            self.stdout.write(self.style.SUCCESS(f"Found {expiring_profiles.count()} profile(s) expiring in {days} days ({target_date}). Sending reminders..."))
            
            for profile in expiring_profiles:
                user = profile.user
                
                # Send Email
                email_sent = send_membership_reminder_email(user, days)
                if email_sent:
                    self.stdout.write(f"  [Email] Sent to {user.email}")
                else:
                    self.stdout.write(self.style.ERROR(f"  [Email] Failed to send to {user.email}"))
                
                # Send Push Notification
                push_sent = send_push_notification(
                    user=user,
                    title=f"Membership expires in {days} days",
                    body="Please renew your membership to keep your access to Premium features.",
                    data={"type": "membership_reminder"}
                )
                if push_sent:
                    self.stdout.write(f"  [Push] Sent to {user.email}")
                else:
                    self.stdout.write(self.style.ERROR(f"  [Push] Failed to send to {user.email}"))

        self.stdout.write(self.style.SUCCESS("Finished sending membership expiration reminders!"))

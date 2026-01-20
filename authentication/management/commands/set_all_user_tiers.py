from django.core.management.base import BaseCommand
from django.contrib.auth.models import User

class Command(BaseCommand):
    help = 'Sets the tier for all non-admin users to either STANDARD or PREMIUM'

    def add_arguments(self, parser):
        parser.add_argument(
            '--tier',
            type=str,
            choices=['STANDARD', 'PREMIUM'],
            required=True,
            help='The tier to apply to all non-admin users'
        )

    def handle(self, *args, **options):
        target_tier = options['tier']
        is_premium_bool = (target_tier == 'PREMIUM')

        # Filter for regular users (not superusers, not staff)
        # Adjust filter if you have different criteria for "non-admin"
        users = User.objects.filter(is_superuser=False, is_staff=False)
        
        total_users = users.count()
        self.stdout.write(f"Found {total_users} non-admin users. Updating to {target_tier}...")

        updated_count = 0
        for user in users:
            try:
                # Access the profile. Assuming OneToOne relation related_name='profile'
                # or implicit reverse relation.
                if hasattr(user, 'profile'):
                    profile = user.profile
                    profile.tier = target_tier
                    profile.is_premium = is_premium_bool
                    profile.save()
                    updated_count += 1
                else:
                    self.stdout.write(self.style.WARNING(f"User {user.username} has no profile. Skipped."))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"Error updating user {user.username}: {e}"))

        self.stdout.write(self.style.SUCCESS(f"Successfully updated {updated_count}/{total_users} users to {target_tier}."))

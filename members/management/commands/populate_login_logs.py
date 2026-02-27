from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from members.models import LoginLog
from django.utils import timezone

class Command(BaseCommand):
    help = 'Populates LoginLog with historical data from User.last_login'

    def handle(self, *args, **options):
        from members.models import LoginLog, Story, Message
        from django.contrib.auth.models import User
        
        users = User.objects.all()
        count = 0
        
        for user in users:
            # Gather potential "login" timestamps for this user
            timestamps = set()
            
            # 1. Last Login (Standard Django field)
            if user.last_login:
                timestamps.add(user.last_login)
            
            # 2. Date Joined (Registration is effectively the first login)
            if user.date_joined:
                timestamps.add(user.date_joined)
                
            # 3. Story creation (User was definitely logged in)
            story_times = Story.objects.filter(user=user).values_list('created_at', flat=True)
            for t in story_times:
                timestamps.add(t)
                
            # 4. Message sending
            msg_times = Message.objects.filter(sender=user).values_list('created_at', flat=True)
            for t in msg_times:
                timestamps.add(t)
            
            # Create a log for each unique timestamp found
            for ts in timestamps:
                if not LoginLog.objects.filter(user=user, timestamp=ts).exists():
                    log = LoginLog(
                        user=user,
                        ip_address='0.0.0.0',
                        user_agent='Historical/Migration Import'
                    )
                    log.save()
                    LoginLog.objects.filter(id=log.id).update(timestamp=ts)
                    count += 1
        
        self.stdout.write(self.style.SUCCESS(f'Successfully created {count} historical login logs from all sources.'))

from django.utils import timezone
from members.models import Profile

class UpdateLastSeenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.user.is_authenticated:
            now = timezone.now()
            # Update the profile's last_seen timestamp
            Profile.objects.filter(user=request.user).update(last_seen=now)
            
            # Record Daily App Access as a LoginLog if it doesn't exist for today
            # This ensures "Today's" logs appear for mobile users who stay logged in
            from members.models import LoginLog
            today = now.date()
            if not LoginLog.objects.filter(user=request.user, timestamp__date=today).exists():
                # Get IP Address
                x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
                ip = x_forwarded_for.split(',')[0] if x_forwarded_for else request.META.get('REMOTE_ADDR')
                user_agent = request.META.get('HTTP_USER_AGENT', '')
                
                LoginLog.objects.create(
                    user=request.user,
                    ip_address=ip,
                    user_agent=f"{user_agent} (Daily Activity)".strip()
                )
        
        response = self.get_response(request)
        return response

from django.utils import timezone
from members.models import Profile

class UpdateLastSeenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.user.is_authenticated:
            # Update the profile's last_seen timestamp
            Profile.objects.filter(user=request.user).update(last_seen=timezone.now())
        
        response = self.get_response(request)
        return response

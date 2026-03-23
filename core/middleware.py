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

from django.http import JsonResponse
from rest_framework_simplejwt.authentication import JWTAuthentication

class RequireActiveMembershipMiddleware:
    """
    Blocks access to core features if the authenticated user's membership has expired.
    Exception paths like payments, auth, and profile fetching are omitted so users can still renew.
    """
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith('/api/') or request.path.startswith('/auth/'):
            # Allow endpoints that expired users MUST access to renew or log in
            allowed_paths = [
                '/api/auth/',
                '/auth/',
                '/api/payments/',
                '/api/home/download-apk/',
                '/api/webhooks/',
                '/admin/',
                '/api/members/me/', # Ensure they can fetch their profile to see it's expired
            ]
            
            # If the path is not in allowed_paths, we check validation
            if not any(request.path.startswith(p) for p in allowed_paths):
                try:
                    # Authenticate user from JWT token
                    auth_result = JWTAuthentication().authenticate(request)
                    if auth_result:
                        user, token = auth_result
                        
                        # Admins bypass the expiry check
                        if not user.is_staff and not user.is_superuser:
                            profile = getattr(user, 'profile', None)
                            if profile and profile.subscription_expiry and profile.subscription_expiry < timezone.now():
                                return JsonResponse(
                                    {
                                        "code": "membership_expired",
                                        "detail": "Membership expired. Please renew your subscription to continue using the app."
                                    },
                                    status=403
                                )
                except Exception:
                    # If JWT decoding fails, pass to view to handle standard 401 unauthenticated
                    pass
                    
        response = self.get_response(request)
        return response

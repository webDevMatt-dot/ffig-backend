from rest_framework import permissions

class IsPremiumUser(permissions.BasePermission):
    """
    Allows access only to premium users.
    """
    def has_permission(self, request, view):
        # Check if user is logged in AND has the premium flag
        # We access profile safely
        return bool(request.user and request.user.is_authenticated and 
                    hasattr(request.user, 'profile') and request.user.profile.is_premium)

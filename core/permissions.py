from rest_framework import permissions

class IsStandardUser(permissions.BasePermission):
    """
    Allows access to Standard and Premium users.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and 
                    hasattr(request.user, 'profile') and 
                    request.user.profile.tier in ['STANDARD', 'PREMIUM'])

class IsPremiumUser(permissions.BasePermission):
    """
    Allows access only to premium users.
    """
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and 
                    hasattr(request.user, 'profile') and 
                    request.user.profile.tier == 'PREMIUM')

from rest_framework import generics, permissions
from .models import Resource
from .serializers import ResourceSerializer

class ResourceListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ResourceSerializer
    queryset = Resource.objects.all().order_by('-created_at')

    def get_queryset(self):
        user = self.request.user
        queryset = Resource.objects.all().order_by('-created_at')

        # 1. Filter by Category (Magazines, Masterclasses, etc.)
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)

        # 2. THE BOUNCER: Security Check 🔒
        # If the user asks for VIP content (Magazine, Class, Newsletter),
        # check if they are actually Premium.
        vip_categories = ['MAG', 'CLASS', 'NEWS', 'POD']
        
        if category in vip_categories:
            # Check the user's profile
            if not hasattr(user, 'profile') or not user.profile.is_premium:
                # If not premium, return an EMPTY list (Hide everything)
                return Resource.objects.none()

        return queryset

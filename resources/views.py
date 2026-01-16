from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import Resource
from .serializers import ResourceSerializer

class ResourceListView(generics.ListAPIView):
    serializer_class = ResourceSerializer
    permission_classes = [IsAuthenticated] # User MUST be logged in

    def get_queryset(self):
        # 1. Start with everything (that is active!)
        queryset = Resource.objects.filter(is_active=True).order_by('-created_at')
        
        user = self.request.user
        
        # 2. Check Premium Status (Support both Tier and Deprecated Boolean)
        is_premium = False
        if hasattr(user, 'profile'):
             # Allow PREMIUM tier or legacy is_premium flag
             is_premium = user.profile.tier == 'PREMIUM' or user.profile.is_premium
        
        # Allow Admins to see everything
        if user.is_staff:
             is_premium = True

        # 3. DEFINITION: What counts as "VIP Only"?
        vip_categories = ['MAG', 'CLASS', 'NEWS', 'POD']
        
        # 4. Global Filter: If not premium, HIDE VIP content from ALL views
        # This prevents "All" from showing content that "Magazines" would hide.
        if not is_premium:
             queryset = queryset.exclude(category__in=vip_categories)

        # 5. Apply the requested category filter
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
            
        return queryset

from rest_framework.permissions import IsAdminUser

class AdminResourceListCreateView(generics.ListCreateAPIView):
    serializer_class = ResourceSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        queryset = Resource.objects.all().order_by('-created_at')
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
        return queryset

class AdminResourceDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Resource.objects.all()
    serializer_class = ResourceSerializer
    permission_classes = [IsAdminUser]

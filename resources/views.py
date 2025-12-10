from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import Resource
from .serializers import ResourceSerializer

class ResourceListView(generics.ListAPIView):
    serializer_class = ResourceSerializer
    permission_classes = [IsAuthenticated] # User MUST be logged in

    def get_queryset(self):
        # 1. Start with everything
        queryset = Resource.objects.all().order_by('-created_at')
        
        # 2. Get the category the app is asking for (e.g., "MAG")
        category = self.request.query_params.get('category')
        user = self.request.user

        # 3. DEFINITION: What counts as "VIP Only"?
        vip_categories = ['MAG', 'CLASS', 'NEWS', 'POD']

        # 4. THE SECURITY CHECK 🔒
        # If the app asks for a VIP category...
        if category in vip_categories:
            # Check if the user is actually Premium
            # We use a safe check (getattr) just in case the profile is missing
            is_premium = False
            if hasattr(user, 'profile'):
                is_premium = user.profile.is_premium
            
            # If they are NOT premium, return NOTHING.
            if not is_premium:
                return Resource.objects.none() 

        # 5. Apply the filter (if the user passed the check)
        if category:
            queryset = queryset.filter(category=category)
            
        return queryset

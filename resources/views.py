from rest_framework import generics, permissions
from .models import Resource
from .serializers import ResourceSerializer

class ResourceListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ResourceSerializer
    queryset = Resource.objects.all().order_by('-created_at')

    # Optional: Add simple filtering
    def get_queryset(self):
        # Start with all resources
        queryset = Resource.objects.all().order_by('-created_at')
        
        # FILTER: Check if the app asked for a specific category
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
            
        return queryset

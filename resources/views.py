from rest_framework import generics, permissions
from .models import Resource
from .serializers import ResourceSerializer

class ResourceListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ResourceSerializer
    queryset = Resource.objects.all().order_by('-created_at')

    # Optional: Add simple filtering
    def get_queryset(self):
        queryset = super().get_queryset()
        category = self.request.query_params.get('type')
        if category:
            queryset = queryset.filter(resource_type=category)
        return queryset

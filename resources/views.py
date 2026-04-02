from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import Resource, ResourceImage, ResourceView
from .serializers import ResourceSerializer, ResourceImageSerializer
from rest_framework.views import APIView
from rest_framework.response import Response

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
            
        # 6. Global Search: Filter by title or description
        search_query = self.request.query_params.get('search', None)
        if search_query:
            from django.db.models import Q
            terms = search_query.split()
            for term in terms:
                queryset = queryset.filter(
                    Q(title__icontains=term) |
                    Q(description__icontains=term)
                )
            
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

class ResourceImageCreateView(generics.CreateAPIView):
    serializer_class = ResourceImageSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        resource_id = self.request.data.get('resource')
        resource = Resource.objects.get(id=resource_id)
        serializer.save(resource=resource)

class ResourceImageDeleteView(generics.DestroyAPIView):
    queryset = ResourceImage.objects.all()
    serializer_class = ResourceImageSerializer
    permission_classes = [IsAdminUser]

class MarkResourceViewed(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            resource = Resource.objects.get(pk=pk, is_active=True)
            ResourceView.objects.get_or_create(user=request.user, resource=resource)
            return Response({"status": "success"})
        except Resource.DoesNotExist:
            return Response({"error": "Resource not found"}, status=404)

class ResourceUnseenCount(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        
        # 1. Base Query: Only Active Resources
        queryset = Resource.objects.filter(is_active=True)
        
        # 2. Replicate the Filtering Logic from ResourceListView to be consistent
        # Check Premium Status
        is_premium = False
        if hasattr(user, 'profile'):
             is_premium = user.profile.tier == 'PREMIUM' or user.profile.is_premium
        if user.is_staff:
             is_premium = True

        vip_categories = ['MAG', 'CLASS', 'NEWS', 'POD']
        if not is_premium:
             queryset = queryset.exclude(category__in=vip_categories)

        # 3. Exclude resources already viewed by this user
        viewed_ids = ResourceView.objects.filter(user=user).values_list('resource_id', flat=True)
        unseen_count = queryset.exclude(id__in=viewed_ids).count()
        
        return Response({"unseen_count": unseen_count})

from rest_framework import generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.db.models import Q
from .models import Profile
from .serializers import ProfileSerializer
from core.permissions import IsPremiumUser

@api_view(['GET'])
@permission_classes([IsPremiumUser])
def premium_content(request):
    return Response({
        "message": "Welcome to the VIP Lounge.",
        "exclusive_data": [
            "Discount Code: FFIG_GOLD_2025",
            "Direct Access to Investors List",
            "Private Coaching Session Link"
        ]
    })


class MemberListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProfileSerializer

    def get_queryset(self):
        queryset = Profile.objects.all()

        # 1. SORTING: Premium users (-is_premium) come first
        queryset = queryset.order_by('-is_premium', 'user__username')

        # 2. SEARCH: Filter by industry or name
        search_query = self.request.query_params.get('search', None)
        industry_query = self.request.query_params.get('industry', None)

        if search_query:
            queryset = queryset.filter(
                Q(user__username__icontains=search_query) | 
                Q(location__icontains=search_query) |
                Q(business_name__icontains=search_query)
            )
        
        if industry_query:
            queryset = queryset.filter(industry=industry_query)

        return queryset

class UserProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProfileSerializer

    # This determines WHICH profile to edit
    def get_object(self):
        # Magic: Always return the profile of the logged-in user
        return self.request.user.profile

from rest_framework import generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.db.models import Q
from .models import Profile
from .serializers import ProfileSerializer
from core.permissions import IsPremiumUser
from rest_framework.views import APIView
from rest_framework.permissions import IsAdminUser
from .models import Profile, BusinessProfile, MarketingRequest, ContentReport
from .serializers import (
    ProfileSerializer, BusinessProfileSerializer, 
    MarketingRequestSerializer, ContentReportSerializer
)

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

# --- USER SUBMISSION VIEWS ---

class BusinessProfileCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BusinessProfileSerializer

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class MarketingRequestCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class ContentReportCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ContentReportSerializer
    
    def perform_create(self, serializer):
        serializer.save(reporter=self.request.user)

# --- ADMIN DASHBOARD API ---

class AdminAnalyticsView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        from django.contrib.auth.models import User
        from members.models import Profile
        from events.models import Ticket
        from django.db.models import Sum

        total_users = User.objects.count()
        active_users = User.objects.filter(is_active=True).count()
        
        # Calculate Tiers
        standard = Profile.objects.filter(tier='STANDARD').count()
        premium = Profile.objects.filter(tier='PREMIUM').count()
        
        # Calculate Revenue (Ticket Sales)
        ticket_revenue = Ticket.objects.aggregate(total=Sum('tier__price'))['total'] or 0
        
        # Calculate Rates
        conv_standard = f"{(standard / total_users * 100):.1f}%" if total_users > 0 else "0%"
        conv_premium = f"{(premium / total_users * 100):.1f}%" if total_users > 0 else "0%"

        return Response({
            "active_users": {
                "daily": active_users, # Using active count as proxy for now
                "monthly": total_users,
            },
            "conversion_rates": {
                "free_to_standard": conv_standard,
                "standard_to_premium": conv_premium,
            },
            "revenue": {
                "ads": 0, # Placeholder until Ads module tracks revenue
                "events": ticket_revenue,
                "total": ticket_revenue
            }
        })

class AdminBusinessProfileListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = BusinessProfile.objects.all().order_by('-created_at')
    serializer_class = BusinessProfileSerializer

class AdminBusinessProfileDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = BusinessProfile.objects.all()
    serializer_class = BusinessProfileSerializer

class AdminMarketingRequestListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = MarketingRequest.objects.all().order_by('-created_at')
    serializer_class = MarketingRequestSerializer

class AdminMarketingRequestDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = MarketingRequest.objects.all()
    serializer_class = MarketingRequestSerializer

class AdminContentReportListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = ContentReport.objects.all().order_by('-created_at')
    serializer_class = ContentReportSerializer

class AdminContentReportDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = ContentReport.objects.all()
    serializer_class = ContentReportSerializer

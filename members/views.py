from rest_framework import generics, permissions, mixins
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.db.models import Q
from django.shortcuts import get_object_or_404
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

class ToggleFavoriteView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, user_id):
        from django.contrib.auth.models import User # Import here to avoid circular imports if any
        
        target_user = get_object_or_404(User, id=user_id)
        profile = request.user.profile
        
        if target_user in profile.favorites.all():
            profile.favorites.remove(target_user)
            is_favorite = False
        else:
            profile.favorites.add(target_user)
            is_favorite = True
            
        return Response({'status': 'success', 'is_favorite': is_favorite})
    
class BlockUserView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, user_id):
        # Block a user
        target_user = get_object_or_404(User, id=user_id)
        if target_user == request.user:
            return Response({"error": "You cannot block yourself"}, status=400)
            
        if not hasattr(request.user, 'profile'):
            Profile.objects.create(user=request.user)

        request.user.profile.blocked_users.add(target_user)
        return Response({"status": "blocked", "user_id": user_id})

    def delete(self, request, user_id):
        # Unblock a user
        target_user = get_object_or_404(User, id=user_id)
        request.user.profile.blocked_users.remove(target_user)
        return Response({"status": "unblocked", "user_id": user_id})

class BlockedUserListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProfileSerializer 

    def get_queryset(self):
        # Return profiles of users I have blocked
        return Profile.objects.filter(user__in=self.request.user.profile.blocked_users.all())


# --- USER SUBMISSION VIEWS ---

class MyBusinessProfileView(generics.RetrieveUpdateDestroyAPIView,
                            mixins.CreateModelMixin):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = BusinessProfileSerializer

    def get_object(self):
        # Return the user's business profile or 404
        return get_object_or_404(BusinessProfile, user=self.request.user)

    def post(self, request, *args, **kwargs):
        if hasattr(request.user, 'business_profile'):
             return Response({'error': 'Business Profile already exists. Use PATCH to update.'}, status=400)
        return self.create(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class MarketingRequestCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class MarketingFeedView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer

    def get_queryset(self):
        return MarketingRequest.objects.filter(status='APPROVED').order_by('-created_at')

class ContentReportCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ContentReportSerializer
    
    def perform_create(self, serializer):
        report = serializer.save(reporter=self.request.user)
        
        # Notify Admins
        admins = User.objects.filter(is_staff=True)
        for admin in admins:
            Notification.objects.create(
                recipient=admin,
                title="New Content Report Filed",
                message=f"{self.request.user.username} reported a {report.get_reported_item_type_display()}: {report.reason}",
            )

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

class AdminModerationActionView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def post(self, request):
        from django.contrib.auth.models import User
        from django.utils import timezone
        
        action = request.data.get('action') # 'WARN', 'SUSPEND', 'BLOCK', 'DELETE'
        target_user_id = request.data.get('target_user_id')
        reason = request.data.get('reason', '')
        
        if not action or not target_user_id:
            return Response({'error': 'Missing action or target_user_id'}, status=400)
            
        target_user = get_object_or_404(User, id=target_user_id)
        
        if action == 'WARN':
            # Set the notice on the profile
            target_user.profile.admin_notice = reason
            target_user.profile.save()
            
            Notification.objects.create(
                recipient=target_user,
                title="Warning from Admin",
                message=f"You have received a warning: {reason}"
            )
            return Response({'status': 'warned'})
            
        elif action == 'SUSPEND':
            # Suspend for 7 days by default, or parse duration
            duration = 7 
            target_user.profile.suspension_expiry = timezone.now() + timedelta(days=duration)
            target_user.profile.admin_notice = f"Suspended for {duration} days: {reason}"
            target_user.profile.save()
            
            # Notify
            Notification.objects.create(
                recipient=target_user,
                title="Account Suspended",
                message=f"Your account has been suspended for {duration} days. Reason: {reason}"
            )
            return Response({'status': 'suspended'})
            
        elif action == 'BLOCK':
            target_user.is_active = False
            target_user.save()
             # Notify (email would be better here since they can't login, but creating notif for record)
            return Response({'status': 'blocked'})
            
        elif action == 'DELETE':
            target_user.delete()
            return Response({'status': 'deleted'})
            
        return Response({'error': 'Invalid action'}, status=400)

# --- NOTIFICATIONS (Admin Only for now) ---
from .serializers import NotificationSerializer
from .models import Notification

class NotificationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        # Return only unread notifications for the user
        return Notification.objects.filter(recipient=self.request.user, is_read=False).order_by('-created_at')

class NotificationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, id=pk, recipient=request.user)
        notification.is_read = True
        notification.save()
        return Response({"status": "marked as read"})

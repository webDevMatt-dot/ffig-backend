from rest_framework import viewsets, generics, permissions, status, mixins
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from .models import Profile
from .serializers import ProfileSerializer
from core.permissions import IsPremiumUser
from rest_framework.views import APIView
from rest_framework.permissions import IsAdminUser
from .models import Profile, BusinessProfile, MarketingRequest, ContentReport
from .serializers import (
    ProfileSerializer, BusinessProfileSerializer, AdminBusinessProfileSerializer,
    MarketingRequestSerializer, AdminMarketingRequestSerializer, ContentReportSerializer,
    NotificationSerializer
)
from .models import Notification

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
        
        # 3. STATUS FILTER: Suspended or Blocked
        status_filter = self.request.query_params.get('status', None)
        if status_filter == 'suspended':
             queryset = queryset.filter(suspension_expiry__gt=timezone.now())
        elif status_filter == 'blocked':
             queryset = queryset.filter(is_blocked=True)

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

class MyMarketingRequestListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer
    
    def get_queryset(self):
        # Return only the logged-in user's requests
        return MarketingRequest.objects.filter(user=self.request.user).order_by('-created_at')

class MarketingRequestUpdateView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer
    
    def get_queryset(self):
        # Ensure user can only edit/delete their own requests
        return MarketingRequest.objects.filter(user=self.request.user)

class MarketingFeedView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MarketingRequestSerializer

    def get_queryset(self):
        return MarketingRequest.objects.filter(status='APPROVED').order_by('-created_at')

class MarketingLikeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        from .models import MarketingLike
        marketing_request = get_object_or_404(MarketingRequest, id=pk)
        
        # Toggle Like
        like, created = MarketingLike.objects.get_or_create(user=request.user, marketing_request=marketing_request)
        if not created:
            like.delete()
            return Response({'status': 'unliked', 'count': marketing_request.likes.count()})
        else:
            # Notify creator via Direct Push
            if marketing_request.user != request.user:
                 from core.services.fcm_service import send_push_notification
                 send_push_notification(
                     marketing_request.user,
                     title="New Like",
                     body=f"{request.user.username} liked your post: {marketing_request.title}",
                     data={
                         "type": "post_like",
                         "post_id": str(marketing_request.id),
                         "sender_name": request.user.username
                     }
                 )
            return Response({'status': 'liked', 'count': marketing_request.likes.count()})

class MarketingCommentView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    from .serializers import MarketingCommentSerializer
    serializer_class = MarketingCommentSerializer

    def get_queryset(self):
        from .models import MarketingComment
        return MarketingComment.objects.filter(marketing_request_id=self.kwargs['pk']).order_by('created_at')

    def perform_create(self, serializer):
        from .models import MarketingComment
        marketing_request = get_object_or_404(MarketingRequest, id=self.kwargs['pk'])
        serializer.save(user=self.request.user, marketing_request=marketing_request)
        
        # Notify creator via Direct Push
        if marketing_request.user != self.request.user:
                from core.services.fcm_service import send_push_notification
                send_push_notification(
                    marketing_request.user,
                    title="New Comment",
                    body=f"{self.request.user.username} commented on your post: {marketing_request.title}",
                    data={
                        "type": "post_comment",
                        "post_id": str(marketing_request.id),
                        "sender_name": self.request.user.username
                    }
                )

class ContentReportCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ContentReportSerializer
    
    def perform_create(self, serializer):
        report = serializer.save(reporter=self.request.user)
        
        # Notify Admins via Direct Push
        from core.services.fcm_service import send_push_notification
        admins = User.objects.filter(is_staff=True)
        for admin in admins:
            send_push_notification(
                admin,
                title="New Content Report Filed",
                body=f"{self.request.user.username} reported a {report.get_reported_item_type_display()}: {report.reason}",
                data={"type": "admin_report"}
            )
            
        # AUTO-SUSPENSION LOGIC
        # If user has > 3 OPEN reports against them, suspend them automatically.
        if report.reported_item_type == 'USER':
             target_user_id = report.reported_item_id
             # Count open reports against this user
             count = ContentReport.objects.filter(
                 reported_item_type='USER', 
                 reported_item_id=target_user_id,
                 status='OPEN'
             ).count()
             
             if count > 3:
                 from django.contrib.auth.models import User
                 from django.utils import timezone
                 from datetime import timedelta
                 try:
                     target_user = User.objects.get(id=target_user_id)
                     if hasattr(target_user, 'profile'):
                         # Auto-suspend for 7 days
                         target_user.profile.suspension_expiry = timezone.now() + timedelta(days=7)
                         target_user.profile.admin_notice = "Account automatically suspended due to multiple reports."
                         target_user.profile.save()
                         
                         # Notify
                         Notification.objects.create(
                            recipient=target_user,
                            title="Account Suspended",
                            message="Your account has been automatically suspended for 7 days due to multiple user reports."
                         )
                 except User.DoesNotExist:
                     pass

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
    serializer_class = AdminBusinessProfileSerializer

class AdminMarketingRequestListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = MarketingRequest.objects.all().order_by('-created_at')
    serializer_class = MarketingRequestSerializer

class AdminMarketingRequestDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = MarketingRequest.objects.all()
    serializer_class = AdminMarketingRequestSerializer

    def perform_update(self, serializer):
        old_status = self.get_object().status
        instance = serializer.save()
        new_status = instance.status

        # If approved, notify ALL users (New Post notification)
        if old_status != 'APPROVED' and new_status == 'APPROVED':
            from core.services.fcm_service import send_push_notification
            from django.contrib.auth.models import User
            
            # Notify all active users
            users = User.objects.filter(is_active=True)
            for user in users:
                send_push_notification(
                    user,
                    title="New Post Alert",
                    body=f"Check out the latest: {instance.title}",
                    data={
                        "type": "new_post",
                        "post_id": str(instance.id),
                        "category": instance.type
                    }
                )

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
        from datetime import timedelta
        
        action = request.data.get('action') # 'WARN', 'SUSPEND', 'BLOCK', 'DELETE'
        target_user_id = request.data.get('target_user_id')
        reason = request.data.get('reason', '')
        
        if not action or not target_user_id:
            return Response({'error': 'Missing action or target_user_id'}, status=400)
            
        target_user = get_object_or_404(User, id=target_user_id)
        
        # Ensure profile exists
        if not hasattr(target_user, 'profile'):
            Profile.objects.create(user=target_user)

        
        if action == 'WARN':
            # Set the notice on the profile
            target_user.profile.admin_notice = reason
            target_user.profile.save()
            
            from core.services.fcm_service import send_push_notification
            send_push_notification(
                recipient=target_user,
                title="Warning from Admin",
                body=f"You have received a warning: {reason}",
                data={"type": "admin_warning"}
            )
            return Response({'status': 'warned'})
            
        elif action == 'SUSPEND':
            # Suspend for 7 days by default, or parse duration
            duration = 7 
            target_user.profile.suspension_expiry = timezone.now() + timedelta(days=duration)
            target_user.profile.admin_notice = f"Suspended for {duration} days: {reason}"
            target_user.profile.save()
            
            # Notify via Direct Push
            from core.services.fcm_service import send_push_notification
            send_push_notification(
                recipient=target_user,
                title="Account Suspended",
                body=f"Your account has been suspended for {duration} days. Reason: {reason}",
                data={"type": "account_suspension"}
            )
            return Response({'status': 'suspended'})
            
        elif action == 'BLOCK':
            target_user.profile.is_blocked = True
            target_user.profile.save()
            # target_user.is_active = False # Don't deactivate so they can see the 'Blocked' dialog
            # target_user.save()
             # Notify (email would be better here since they can't login, but creating notif for record)
            return Response({'status': 'blocked'})
            
        elif action == 'DELETE':
            target_user.delete()
            return Response({'status': 'deleted'})
            
        return Response({'error': 'Invalid action'}, status=400)

        return Response({'error': 'Invalid action'}, status=400)

class AdminUserUpdateView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAdminUser]
    queryset = User.objects.all()
    # Lazy import or direct import if possible, but let's try direct first
    from authentication.serializers import UserSerializer
    serializer_class = UserSerializer

# --- NOTIFICATIONS (Admin Only for now) ---


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

from .models import Story, StoryView
from .serializers import StorySerializer, StoryGroupSerializer, StoryViewSerializer
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Exists, OuterRef

class StoryViewSet(viewsets.ModelViewSet):
    queryset = Story.objects.all()
    serializer_class = StorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        story = serializer.save(user=self.request.user)
        
        # Notify all active users via Direct Push
        from core.services.fcm_service import send_push_notification
        from django.contrib.auth.models import User
        
        # We notify everyone EXCEPT the creator
        others = User.objects.filter(is_active=True).exclude(id=self.request.user.id)
        for user in others:
            send_push_notification(
                user,
                title="New Story Uploaded",
                body=f"{self.request.user.username} just posted a new story!",
                data={
                    "type": "story_uploaded",
                    "story_id": str(story.id),
                    "sender_id": str(self.request.user.id)
                },
                tag="story_update" # Group story updates
            )

    def get_queryset(self):
        # 24 hour filter
        now = timezone.now()
        time_threshold = now - timedelta(hours=24)
        return Story.objects.filter(created_at__gte=time_threshold).order_by('created_at')

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.user != request.user:
            return Response({'error': 'You cannot delete this story'}, status=403)
        self.perform_destroy(instance)
        return Response(status=status.HTTP_204_NO_CONTENT)

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        
        # Annotate with seen status efficiently
        is_seen_subquery = StoryView.objects.filter(
            story=OuterRef('pk'),
            viewer=request.user
        )
        stories = queryset.annotate(is_seen=Exists(is_seen_subquery)).select_related('user', 'user__profile')
        
        # Group by user
        grouped = {}
        for story in stories:
            uid = story.user.id
            if uid not in grouped:
                # Basic user info
                username = story.user.username
                photo = None
                if hasattr(story.user, 'profile'):
                    photo = story.user.profile.photo.url if story.user.profile.photo else story.user.profile.photo_url
                    
                grouped[uid] = {
                    'user_id': uid,
                    'username': username,
                    'user_photo': photo,
                    'has_unseen': False,
                    'stories': []
                }
            
            # Add story
            grouped[uid]['stories'].append(story)
            if not story.is_seen:
                 grouped[uid]['has_unseen'] = True

        # Convert to list and serialize using the Group serializer structure
        results = []
        for uid, data in grouped.items():
            # We need to manually serialize the story objects because we are constructing a custom dict
            # or we can use the serializer on the list of stories.
            # Let's use the serializer for stories to ensure all fields (media_url etc) are correct.
            story_serializer = StorySerializer(data['stories'], many=True, context={'request': request})
            data['stories'] = story_serializer.data
            results.append(data)
            
        return Response(results)

    @action(detail=True, methods=['post'], url_path='seen')
    def mark_seen(self, request, pk=None):
        story = self.get_object()
        StoryView.objects.get_or_create(story=story, viewer=request.user)
        return Response({'status': 'seen'})

    @action(detail=True, methods=['post'], url_path='reply')
    def reply(self, request, pk=None):
        story = self.get_object()
        content = request.data.get('message')
        if not content:
            return Response({'error': 'Message content is required'}, status=400)

        # 1. Get or Create Conversation
        # Ensure we always order user_a < user_b to convert unique constraint
        if request.user.id < story.user.id:
            user_a, user_b = request.user, story.user
        else:
            user_a, user_b = story.user, request.user
            
        from .models import Conversation, Message
        conversation, _ = Conversation.objects.get_or_create(user_a=user_a, user_b=user_b)

        # 2. Create Message
        Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content=content,
            story=story
        )

        return Response({'status': 'sent', 'conversation_id': conversation.id})

    @action(detail=True, methods=['get'], url_path='views')
    def get_views(self, request, pk=None):
        story = self.get_object()
        if story.user != request.user:
            return Response({'error': 'Unauthorized'}, status=403)

        views = StoryView.objects.filter(story=story).select_related('viewer', 'viewer__profile').order_by('-seen_at')
        
        # Manual serialize for speed/simplicity
        data = []
        for v in views:
            photo = None
            if hasattr(v.viewer, 'profile'):
                photo = v.viewer.profile.photo.url if v.viewer.profile.photo else v.viewer.profile.photo_url
            
            data.append({
                'viewer_id': v.viewer.id,
                'username': v.viewer.username,
                'profile_photo': photo,
                'seen_at': v.seen_at
            })
            
        return Response(data)



# --- WIX WEBHOOK INTEGRATION (Ultra-Robust Debug Version) ---

@api_view(['POST'])
@permission_classes([permissions.AllowAny]) 
def wix_webhook(request):
    """
    Ultra-robust listener for Wix Webhooks with deep logging.
    Designed to catch sync issues by logging the raw payload and headers.
    """
    import os
    import json
    
    # 1. Detailed Logging for Debugging
    print("--- [WIX WEBHOOK START] ---")
    print(f"Headers: {dict(request.headers)}")
    
    # 2. Security Check
    wix_secret = os.environ.get('WIX_WEBHOOK_SECRET', 'test_secret_123')
    received_secret = request.headers.get('X-Wix-Secret') or request.GET.get('secret')
    
    if received_secret != wix_secret:
        print(f"❌ [Wix Webhook] AUTH FAILED. Expected: {wix_secret}, Received: {received_secret}")
        return Response({"error": "Unauthorized"}, status=403)

    try:
        data = request.data
        print(f"📩 [Wix Webhook] Raw Payload: {json.dumps(data)}")
        
        # 3. Greedy Email Detection (Nested search)
        email = None
        
        def find_email(obj):
            if isinstance(obj, dict):
                # Check direct fields
                for key in ['email', 'emailAddress', 'emails']:
                    val = obj.get(key)
                    if val:
                        if isinstance(val, list) and len(val) > 0:
                            if isinstance(val[0], dict): return val[0].get('email')
                            return val[0]
                        if isinstance(val, str): return val
                # Recurse
                for v in obj.values():
                    found = find_email(v)
                    if found: return found
            elif isinstance(obj, list):
                for item in obj:
                    found = find_email(item)
                    if found: return found
            return None

        email = find_email(data)
        
        # 4. Greedy Label Detection
        labels = []
        def find_labels(obj):
            if isinstance(obj, dict):
                if 'labels' in obj and isinstance(obj['labels'], list):
                    return obj['labels']
                for v in obj.values():
                    found = find_labels(v)
                    if found: return found
            elif isinstance(obj, list):
                for item in obj:
                    found = find_labels(item)
                    if found: return found
            return []

        labels = find_labels(data)
        
        print(f"🔍 [Wix Webhook] Syncing Email: {email}, Labels: {labels}")

        if not email:
            print("❌ [Wix Webhook] CRITICAL: No email found in payload.")
            return Response({"error": "No email found"}, status=400)

        # 5. Logic: Update User Profile
        try:
            # Match user by email
            user = User.objects.get(email__iexact=email)
            
            # Ensure profile exists
            if not hasattr(user, 'profile'):
                print(f"📝 [Wix Webhook] Profile missing for {user.username}. Creating...")
                Profile.objects.create(user=user)
            
            profile = user.profile
            old_tier = profile.tier
            new_tier = 'FREE'
            
            # Convert labels to uppercase string for matching
            labels_str = "|".join([str(l).upper() for l in labels])
            print(f"🏷️ [Wix Webhook] Processing Labels String: {labels_str}")

            # Flexible matching: search for 'PREMIUM' or 'STANDARD' anywhere in labels
            if "PREMIUM" in labels_str:
                new_tier = 'PREMIUM'
            elif "STANDARD" in labels_str:
                new_tier = 'STANDARD'
                
            if old_tier != new_tier:
                profile.tier = new_tier
                profile.is_premium = (new_tier == 'PREMIUM')
                profile.save()
                
                print(f"✅ [Wix Webhook] SUCCESS: {email} updated from {old_tier} to {new_tier}")
                
                # Direct Push to User (No in-app record)
                from core.services.fcm_service import send_push_notification
                send_push_notification(
                    user,
                    title="Account Upgraded",
                    body=f"Success! Your membership has been synced with Wix. You are now a {new_tier} member.",
                    data={"type": "account_upgrade"}
                )
                return Response({"status": "success", "updated": True, "new_tier": new_tier})
            
            print(f"ℹ️ [Wix Webhook] No change needed. {email} is already {old_tier}")
            return Response({"status": "success", "updated": False})

        except User.DoesNotExist:
            print(f"⚠️ [Wix Webhook] User {email} not found in App DB. Sync ignored.")
            return Response({"status": "ignored", "message": "User not found in app"})

    except Exception as e:
        print(f"🔥 [Wix Webhook] INTERNAL ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({"error": str(e)}, status=500)
    finally:
        print("--- [WIX WEBHOOK END] ---")

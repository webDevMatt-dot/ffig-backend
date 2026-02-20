"""
URL configuration for ffig_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include, re_path
from django.views.static import serve
from django.http import HttpResponse
from django.contrib.auth.models import User
from django.conf import settings
from django.conf.urls.static import static
import os

# APK Directory
APK_ROOT = os.path.join(settings.BASE_DIR, 'mobile_app', 'web')

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from events.views import (
    FeaturedEventView, EventListView, EventDetailView, MyTicketsView, purchase_ticket, 
    TicketTierCreateView, TicketTierDeleteView, EventDeleteView,
    EventSpeakerCreateView, EventSpeakerDeleteView,
    AgendaItemCreateView, AgendaItemDeleteView,
    EventFAQCreateView, EventFAQDeleteView
)
from members.views import (
    MemberListView, UserProfileView, premium_content,
    MyBusinessProfileView, MarketingRequestCreateView, ContentReportCreateView,
    AdminAnalyticsView, AdminBusinessProfileListView, AdminBusinessProfileDetailView, 
    AdminMarketingRequestListView, AdminMarketingRequestDetailView,
    AdminContentReportListView, AdminContentReportDetailView, AdminModerationActionView,
    NotificationListView, NotificationMarkReadView,
    ToggleFavoriteView, BlockUserView, BlockedUserListView, MarketingFeedView,
    MarketingLikeView, MarketingCommentView, MyMarketingRequestListView, MarketingRequestUpdateView,
    StoryViewSet, AdminUserUpdateView, wix_webhook
)
from resources.views import ResourceListView, AdminResourceListCreateView, AdminResourceDetailView
from chat.views import ConversationListView, MessageListView, SendMessageView, UnreadCountView, CommunityChatView, ChatSearchView, ClearChatView, MuteChatView
from home.views import download_latest_apk

urlpatterns = [
    path('admin/', admin.site.urls),
    
    path('api/', include('authentication.urls')),
    path('api/premium/', premium_content, name='premium-content'),
    path('api/events/featured/', FeaturedEventView.as_view(), name='featured-events'),
    path('api/events/', EventListView.as_view(), name='event-list'),
    path('api/events/<int:pk>/', EventDetailView.as_view(), name='event-detail'),
    path('api/events/<int:pk>/purchase/', purchase_ticket, name='purchase-ticket'),
    path('api/events/<int:pk>/delete/', EventDeleteView.as_view(), name='event-delete'),
    path('api/events/my-tickets/', MyTicketsView.as_view(), name='my-tickets'),
    
    # Nested Items
    path('api/events/speakers/', EventSpeakerCreateView.as_view(), name='speaker-create'),
    path('api/events/speakers/<int:pk>/', EventSpeakerDeleteView.as_view(), name='speaker-delete'),
    path('api/events/agenda/', AgendaItemCreateView.as_view(), name='agenda-create'),
    path('api/events/agenda/<int:pk>/', AgendaItemDeleteView.as_view(), name='agenda-delete'),
    path('api/events/faqs/', EventFAQCreateView.as_view(), name='faq-create'),
    path('api/events/faqs/<int:pk>/', EventFAQDeleteView.as_view(), name='faq-delete'),
    path('api/events/my-tickets/', MyTicketsView.as_view(), name='my-tickets'),
    path('api/events/tiers/', TicketTierCreateView.as_view(), name='tier-create'),
    path('api/events/tiers/<int:pk>/', TicketTierDeleteView.as_view(), name='tier-delete'),
    path('api/members/', MemberListView.as_view(), name='member-list'),
    path('api/members/me/', UserProfileView.as_view(), name='my-profile'),
    path('api/resources/', ResourceListView.as_view(), name='resource-list'),
    path('api/resources/', ResourceListView.as_view(), name='resource-list'),
    
    # Explicit override to ensuring routing works
    path('api/home/download-apk/', download_latest_apk, name='direct-download-apk'),
    path('api/home/', include('home.urls')),
    
    # Admin Resource Management
    path('api/admin/resources/', AdminResourceListCreateView.as_view(), name='admin-resource-list'),
    path('api/admin/resources/<int:pk>/', AdminResourceDetailView.as_view(), name='admin-resource-detail'),

    # Phase 2: RBAC & Admin
    path('api/admin/analytics/', AdminAnalyticsView.as_view(), name='admin-analytics'),
    
    # Admin Approvals
    path('api/admin/approvals/business/', AdminBusinessProfileListView.as_view(), name='admin-business-list'),
    path('api/admin/approvals/business/<int:pk>/', AdminBusinessProfileDetailView.as_view(), name='admin-business-detail'),
    path('api/admin/approvals/marketing/', AdminMarketingRequestListView.as_view(), name='admin-marketing-list'),
    path('api/admin/approvals/marketing/<int:pk>/', AdminMarketingRequestDetailView.as_view(), name='admin-marketing-detail'),
    
    # Admin Moderation
    path('api/admin/moderation/reports/', AdminContentReportListView.as_view(), name='admin-report-list'),
    path('api/admin/moderation/reports/<int:pk>/', AdminContentReportDetailView.as_view(), name='admin-report-detail'),
    path('api/admin/moderation/actions/', AdminModerationActionView.as_view(), name='admin-moderation-action'),

    path('api/admin/moderation/actions/', AdminModerationActionView.as_view(), name='admin-moderation-action'),
    
    # Admin User Management
    path('api/admin/users/<int:pk>/', AdminUserUpdateView.as_view(), name='admin-user-update'),

    # User Submissions
    path('api/members/me/business/', MyBusinessProfileView.as_view(), name='my-business-profile'),
    path('api/members/me/business/', MyBusinessProfileView.as_view(), name='my-business-profile'),
    path('api/members/me/marketing/', MarketingRequestCreateView.as_view(), name='create-marketing-request'),
    path('api/members/me/marketing/list/', MyMarketingRequestListView.as_view(), name='my-marketing-list'),
    path('api/members/me/marketing/<int:pk>/', MarketingRequestUpdateView.as_view(), name='update-marketing-request'),
    path('api/members/marketing/feed/', MarketingFeedView.as_view(), name='marketing-feed'),
    path('api/members/marketing/<int:pk>/like/', MarketingLikeView.as_view(), name='marketing-like'),
    path('api/members/marketing/<int:pk>/comments/', MarketingCommentView.as_view(), name='marketing-comments'),
    
    # Stories
    path('api/members/stories/', StoryViewSet.as_view({'get': 'list', 'post': 'create'}), name='story-list'),
    path('api/members/stories/<int:pk>/', StoryViewSet.as_view({'delete': 'destroy'}), name='story-detail'),
    path('api/members/stories/<int:pk>/reply/', StoryViewSet.as_view({'post': 'reply'}), name='story-reply'),

    path('api/members/report/', ContentReportCreateView.as_view(), name='create-content-report'),
    path('api/members/report/', ContentReportCreateView.as_view(), name='create-content-report'),
    path('api/members/favorites/toggle/<int:user_id>/', ToggleFavoriteView.as_view(), name='toggle-favorite'),
    
    # Blocking
    path('api/members/block/<int:user_id>/', BlockUserView.as_view(), name='block-user'),
    path('api/members/blocked/', BlockedUserListView.as_view(), name='blocked-user-list'),

    path('api/chat/conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('api/chat/messages/send/', SendMessageView.as_view(), name='send-message'),
    path('api/chat/conversations/<int:pk>/mute/', MuteChatView.as_view(), name='mute-chat'),
    path('api/chat/conversations/<int:pk>/clear/', ClearChatView.as_view(), name='clear-chat'),
    path('api/chat/conversations/<int:pk>/messages/', MessageListView.as_view(), name='message-list'),
    path('api/chat/unread-count/', UnreadCountView.as_view(), name='unread-count'),
    path('api/chat/conversations/<int:pk>/messages/', MessageListView.as_view(), name='message-list'),
    path('api/chat/unread-count/', UnreadCountView.as_view(), name='unread-count'),
    path('api/chat/community/', CommunityChatView.as_view(), name='community-chat'),
    path('api/chat/search/', ChatSearchView.as_view(), name='chat-search'),

    # Redirect /app.apk to the download endpoint
    path('app.apk', download_latest_apk),
    
    # Explicitly serve media files (Required for Render/Production if not using S3)
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),

    # Notifications
    path('api/notifications/', NotificationListView.as_view(), name='notification-list'),
    path('api/notifications/<int:pk>/read/', NotificationMarkReadView.as_view(), name='notification-read'),

    # Wix Webhooks
    path('api/webhooks/wix/', wix_webhook, name='wix-webhook'),
]

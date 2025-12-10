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
from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from events.views import FeaturedEventView, EventListView, EventDetailView
from members.views import MemberListView, UserProfileView, premium_content
from resources.views import ResourceListView
from chat.views import ConversationListView, MessageListView, SendMessageView, UnreadCountView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('authentication.urls')),
    path('api/premium/', premium_content, name='premium-content'),
    path('api/events/featured/', FeaturedEventView.as_view(), name='featured-events'),
    path('api/events/', EventListView.as_view(), name='event-list'),
    path('api/events/<int:pk>/', EventDetailView.as_view(), name='event-detail'),
    path('api/members/', MemberListView.as_view(), name='member-list'),
    path('api/members/me/', UserProfileView.as_view(), name='my-profile'),
    path('api/resources/', ResourceListView.as_view(), name='resource-list'),
    path('api/chat/conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('api/chat/messages/send/', SendMessageView.as_view(), name='send-message'),
    path('api/chat/conversations/<int:pk>/messages/', MessageListView.as_view(), name='message-list'),
    path('api/chat/unread-count/', UnreadCountView.as_view(), name='unread-count'),
]

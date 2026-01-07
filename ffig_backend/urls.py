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
from django.http import HttpResponse
from django.contrib.auth.models import User
from django.conf import settings
from django.conf.urls.static import static

# --- THE MAGIC VIEW ---
def force_admin_create(request):
    try:
        # Get or Create the user 'admin'
        user, created = User.objects.get_or_create(username='admin', defaults={'email': 'admin@example.com'})
        
        # FORCE the password to be set correctly
        user.set_password('ChangeMe123!')
        user.is_staff = True
        user.is_superuser = True
        user.save()
        
        status = "Created new user" if created else "Updated existing user"
        return HttpResponse(f"SUCCESS: {status}. <br>Login: <b>admin</b> <br>Password: <b>ChangeMe123!</b>")
    except Exception as e:
        return HttpResponse(f"ERROR: {str(e)}")
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from events.views import FeaturedEventView, EventListView, EventDetailView
from members.views import MemberListView, UserProfileView, premium_content
from resources.views import ResourceListView, AdminResourceListCreateView, AdminResourceDetailView
from chat.views import ConversationListView, MessageListView, SendMessageView, UnreadCountView

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # The Magic Link
    path('make-admin/', force_admin_create),
    path('api/', include('authentication.urls')),
    path('api/premium/', premium_content, name='premium-content'),
    path('api/events/featured/', FeaturedEventView.as_view(), name='featured-events'),
    path('api/events/', EventListView.as_view(), name='event-list'),
    path('api/events/<int:pk>/', EventDetailView.as_view(), name='event-detail'),
    path('api/members/', MemberListView.as_view(), name='member-list'),
    path('api/members/me/', UserProfileView.as_view(), name='my-profile'),
    path('api/resources/', ResourceListView.as_view(), name='resource-list'),
    path('api/home/', include('home.urls')),
    
    # Admin Resource Management
    path('api/admin/resources/', AdminResourceListCreateView.as_view(), name='admin-resource-list'),
    path('api/admin/resources/<int:pk>/', AdminResourceDetailView.as_view(), name='admin-resource-detail'),

    path('api/chat/conversations/', ConversationListView.as_view(), name='conversation-list'),
    path('api/chat/messages/send/', SendMessageView.as_view(), name='send-message'),
    path('api/chat/conversations/<int:pk>/messages/', MessageListView.as_view(), name='message-list'),
    path('api/chat/unread-count/', UnreadCountView.as_view(), name='unread-count'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

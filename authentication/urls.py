from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import welcome, RegisterView, AdminPasswordResetView, CustomTokenObtainPairView, AdminUserListView, AdminUserDetailView

urlpatterns = [
    path('welcome/', welcome, name='welcome'),

    # The Login Endpoint
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
    
    # Admin Password Reset
    path('admin/reset-password/', AdminPasswordResetView.as_view(), name='admin_password_reset'),
    
    # Admin User Management
    path('admin/users/', AdminUserListView.as_view(), name='admin_user_list'),
    path('admin/users/<int:pk>/', AdminUserDetailView.as_view(), name='admin_user_detail'),
]

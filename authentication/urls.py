from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    welcome, RegisterView, AdminPasswordResetView, CustomTokenObtainPairView, 
    AdminUserListView, AdminUserDetailView, UserPasswordChangeView, UserDeleteView,
    PasswordResetRequestOTPView, PasswordResetConfirmOTPView,
    VerifySignupOTPView, ResendSignupOTPView
)

urlpatterns = [
    path('welcome/', welcome, name='welcome'),

    # The Login Endpoint
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', RegisterView.as_view(), name='auth_register'),
    path('auth/register/verify-otp/', VerifySignupOTPView.as_view(), name='auth_register_verify_otp'),
    path('auth/register/resend-otp/', ResendSignupOTPView.as_view(), name='auth_register_resend_otp'),
    
    # Password Reset (OTP-based)
    path('auth/password/reset/request-otp/', PasswordResetRequestOTPView.as_view(), name='password_reset_request_otp'),
    path('auth/password/reset/confirm-otp/', PasswordResetConfirmOTPView.as_view(), name='password_reset_confirm_otp'),
    
    # User Password Change (Self)
    path('auth/password/change/', UserPasswordChangeView.as_view(), name='user_password_change'),

    path('auth/delete/', UserDeleteView.as_view(), name='user_delete'),
    
    # Admin Password Reset
    path('admin/reset-password/', AdminPasswordResetView.as_view(), name='admin_password_reset'),
    
    # Admin User Management
    path('admin/users/', AdminUserListView.as_view(), name='admin_user_list'),
    path('admin/users/<int:pk>/', AdminUserDetailView.as_view(), name='admin_user_detail'),
]

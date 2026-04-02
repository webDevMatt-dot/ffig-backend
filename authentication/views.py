from django.http import JsonResponse
from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from django.contrib.auth.models import User
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from django.utils import timezone
from django.contrib.auth.hashers import make_password, check_password
from django.core.mail import send_mail
from django.core.cache import cache
import random
import string
import datetime

from .serializers import RegisterSerializer, CustomTokenObtainPairSerializer, UserSerializer
from .models import PasswordResetOTP, SignupOTP

def welcome(request):
    return JsonResponse({"message": "Welcome to the FFIG API!"})

class PasswordResetRequestOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        sender_email = request.data.get('sender_email', 'admin@femalefoundersinitiative.com')

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        # Basic IP-based rate limiting (3 requests per IP per minute)
        ip = request.META.get('REMOTE_ADDR')
        cache_key = f"otp_request_rl_{ip}_{email}"
        requests_count = cache.get(cache_key, 0)
        if requests_count >= 3:
            return Response({"message": "If an account exists with this email, an OTP has been sent."}, status=status.HTTP_200_OK)
        
        cache.set(cache_key, requests_count + 1, timeout=60)

        try:
            user = User.objects.filter(email__iexact=email).first()
            if not user:
                 raise User.DoesNotExist

            
            # Generate 6-digit OTP
            otp = ''.join(random.choices(string.digits, k=6))
            
            # Hash OTP
            otp_hash = make_password(otp)
            
            # Store in DB
            expires_at = timezone.now() + datetime.timedelta(minutes=10)
            PasswordResetOTP.objects.create(
                user=user,
                email=email,
                otp_hash=otp_hash,
                expires_at=expires_at
            )
            
            # Send Email
            subject = 'Your Password Reset OTP'
            
            # HTML Template (Branded)
            html_message = f"""
            <html>
            <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
                <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px;">
                    <div style="text-align: center; margin-bottom: 20px;">
                        <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
                    </div>
                    <h2 style="color: #8B4513; margin-top: 0;">Password Reset OTP</h2>
                    <p>Hi {user.first_name or user.username},</p>
                    <p>We received a request to reset your password. Please use the following one-time password (OTP) to proceed:</p>
                    
                    <div style="background-color: #f9f9f9; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
                        <span style="font-size: 32px; font-weight: bold; color: #8B4513; letter-spacing: 5px;">{otp}</span>
                    </div>
                    
                    <p>This code will expire in <strong>10 minutes</strong>.</p>
                    
                    <p>If you did not request a password reset, please ignore this email or contact support if you have concerns.</p>
                    
                    <p>Best regards,<br>The Female Founders Initiative Global Team</p>
                </div>
            </body>
            </html>
            """
            
            plain_message = f'Your one-time password to reset your FFIG account password is: {otp}\n\nIt will expire in 10 minutes.'
            
            try:
                 send_mail(
                    subject,
                    plain_message,
                    sender_email,
                    [email],
                    html_message=html_message,
                    fail_silently=False,
                )
            except Exception as e:
                import traceback
                print(f"Failed to send email: {e}")
                traceback.print_exc()


        except User.DoesNotExist:
            # Do nothing to prevent email enumeration
            pass

        # Always return 200 generic response
        return Response({"message": "If an account exists with this email, an OTP has been sent."}, status=status.HTTP_200_OK)

class PasswordResetConfirmOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        otp = request.data.get('otp', '').strip()
        new_password = request.data.get('new_password')

        if not email or not otp or not new_password:
            return Response({"error": "Email, OTP, and new_password are required."}, status=status.HTTP_400_BAD_REQUEST)

        # IP + Email Rate limiting for bad attempts (Lockout after 5 attempts)
        ip = request.META.get('REMOTE_ADDR')
        lockout_key = f"otp_lockout_{ip}_{email}"
        failed_attempts = cache.get(lockout_key, 0)

        if failed_attempts >= 5:
             return Response({"error": "Too many failed attempts. Try again later."}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        # Find latest valid OTP record
        try:
            otp_record = PasswordResetOTP.objects.filter(
                email=email,
                is_used=False,
                expires_at__gt=timezone.now(),
                attempts__lt=5
            ).latest('created_at')
        except PasswordResetOTP.DoesNotExist:
            cache.set(lockout_key, failed_attempts + 1, timeout=300) # Lockout for 5 minutes
            return Response({"error": "Invalid or expired OTP."}, status=status.HTTP_400_BAD_REQUEST)

        # Compare provided OTP against stored hash
        if not check_password(otp, otp_record.otp_hash):
            otp_record.attempts += 1
            otp_record.save()
            cache.set(lockout_key, failed_attempts + 1, timeout=300)
            return Response({"error": "Invalid or expired OTP."}, status=status.HTTP_400_BAD_REQUEST)

        # Valid OTP: Set new password
        user = otp_record.user
        user.set_password(new_password)
        user.save()

        # Invalidate OTP
        otp_record.is_used = True
        otp_record.save()

        # Reset lockout counter on success
        cache.delete(lockout_key)

        return Response({"message": "Password successfully reset."}, status=status.HTTP_200_OK)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

    def perform_create(self, serializer):
        user = serializer.save()
        
        # Generate 6-digit OTP
        otp = ''.join(random.choices(string.digits, k=6))
        otp_hash = make_password(otp)
        
        # Store in DB
        expires_at = timezone.now() + datetime.timedelta(minutes=15)
        SignupOTP.objects.create(
            user=user,
            email=user.email,
            otp_hash=otp_hash,
            expires_at=expires_at
        )
        
        # Send Email
        subject = 'Verify Your Email - Female Founders Initiative Global'
        
        html_message = f"""
        <html>
        <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px; border-radius: 12px;">
                <div style="text-align: center; margin-bottom: 20px;">
                    <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
                </div>
                <h2 style="color: #8B4513; margin-top: 0; text-align: center;">Verify Your Email</h2>
                <p>Hi {user.first_name or user.username},</p>
                <p>Thank you for joining the Female Founders Initiative Global! To complete your registration, please use the following one-time password (OTP) to verify your email address:</p>
                
                <div style="background-color: #f9f9f9; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0; border: 1px dashed #8B4513;">
                    <span style="font-size: 32px; font-weight: bold; color: #8B4513; letter-spacing: 5px;">{otp}</span>
                </div>
                
                <p>This code will expire in <strong>15 minutes</strong>.</p>
                <p>Once verified, you'll have full access to our global network of female founders.</p>
                
                <p>Best regards,<br>The Female Founders Initiative Global Team</p>
            </div>
        </body>
        </html>
        """
        
        plain_message = f'Your verification code for FFIG is: {otp}\n\nIt will expire in 15 minutes.'
        
        try:
            send_mail(
                subject,
                plain_message,
                'admin@femalefoundersinitiative.com',
                [user.email],
                html_message=html_message,
                fail_silently=False,
            )
        except Exception as e:
            print(f"Failed to send verification email: {e}")

class VerifySignupOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        otp = request.data.get('otp', '').strip()

        if not email or not otp:
            return Response({"error": "Email and OTP are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            otp_record = SignupOTP.objects.filter(
                email=email,
                is_used=False,
                expires_at__gt=timezone.now()
            ).latest('created_at')
        except SignupOTP.DoesNotExist:
            return Response({"error": "Invalid or expired OTP."}, status=status.HTTP_400_BAD_REQUEST)

        if not check_password(otp, otp_record.otp_hash):
            otp_record.attempts += 1
            otp_record.save()
            return Response({"error": "Invalid or expired OTP."}, status=status.HTTP_400_BAD_REQUEST)

        # Valid OTP: Activate user
        user = otp_record.user
        user.is_active = True
        user.save()

        # Invalidate OTP
        otp_record.is_used = True
        otp_record.save()

        # Note: Activation signals (welcome email, admin push) will be handled here
        # since we moved them from the post_save signal in members/models.py
        from members.models import Profile
        try:
             # Manually trigger the welcome sequence that we moved
             from core.services.fcm_service import send_push_notification
             from core.services.email_service import send_welcome_email
             
             # 1. Admin Push
             admins = User.objects.filter(is_staff=True)
             for admin in admins:
                send_push_notification(
                    admin,
                    title="New User Verified",
                    body=f"{user.username} has joined FFIG.",
                    data={"type": "admin_alert", "user_id": str(user.id)}
                )
             
             # 2. Welcome Email
             send_welcome_email(user)
        except Exception as e:
            print(f"Error in post-verification sequence: {e}")

        return Response({"message": "Email successfully verified. You can now log in."}, status=status.HTTP_200_OK)

class ResendSignupOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()

        if not email:
            return Response({"error": "Email is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email__iexact=email, is_active=False)
            
            # Rate limiting check (e.g., 1 min between resends)
            last_otp = SignupOTP.objects.filter(user=user).order_by('-created_at').first()
            if last_otp and (timezone.now() - last_otp.created_at).total_seconds() < 60:
                return Response({"error": "Please wait a minute before requesting another code."}, status=status.HTTP_429_TOO_MANY_REQUESTS)

            # Generate new OTP
            otp = ''.join(random.choices(string.digits, k=6))
            otp_hash = make_password(otp)
            
            expires_at = timezone.now() + datetime.timedelta(minutes=15)
            SignupOTP.objects.create(
                user=user,
                email=email,
                otp_hash=otp_hash,
                expires_at=expires_at
            )
            
            # Send Email
            subject = 'Your New Verification Code - FFIG'
            html_message = f"""
            <html>
            <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
                <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px; border-radius: 12px;">
                    <div style="text-align: center; margin-bottom: 20px;">
                        <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
                    </div>
                    <h2 style="color: #8B4513; margin-top: 0; text-align: center;">New Verification Code</h2>
                    <p>Hi {user.first_name or user.username},</p>
                    <p>Here is your new verification code as requested:</p>
                    
                    <div style="background-color: #f9f9f9; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0; border: 1px dashed #8B4513;">
                        <span style="font-size: 32px; font-weight: bold; color: #8B4513; letter-spacing: 5px;">{otp}</span>
                    </div>
                    
                    <p>This code will expire in <strong>15 minutes</strong>.</p>
                    <p>Best regards,<br>The Female Founders Initiative Global Team</p>
                </div>
            </body>
            </html>
            """
            
            send_mail(
                subject,
                f'Your new verification code is: {otp}',
                'admin@femalefoundersinitiative.com',
                [email],
                html_message=html_message,
            )
            
            return Response({"message": "New OTP sent to your email."}, status=status.HTTP_200_OK)

        except User.DoesNotExist:
            return Response({"error": "No unverified account found with this email."}, status=status.HTTP_404_NOT_FOUND)

class UserPasswordChangeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')

        if not old_password or not new_password:
             return Response({"error": "Both old and new passwords are required."}, status=status.HTTP_400_BAD_REQUEST)

        if not user.check_password(old_password):
            return Response({"error": "Invalid current password."}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save()
        return Response({"message": "Password updated successfully."})

class AdminPasswordResetView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        user_id = request.data.get('user_id')
        new_password = request.data.get('new_password')

        if not user_id or not new_password:
            return Response({"error": "User ID and new password are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(id=user_id)
            user.set_password(new_password)
            user.save()
            return Response({"message": f"Password for {user.username} has been reset successfully."})
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

from rest_framework import filters

class AdminUserListView(generics.ListAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]
    filter_backends = [filters.SearchFilter]
    search_fields = ['username', 'email', 'first_name', 'last_name']
    
    def get_search_param(self, request):
        return request.query_params.get('q') or super().get_search_param(request)

    def get_queryset(self):
        queryset = super().get_queryset()
        q = self.request.query_params.get('q')
        if q:
            from django.db.models import Q
            queryset = queryset.filter(
                Q(username__icontains=q) |
                Q(email__icontains=q) |
                Q(first_name__icontains=q) |
                Q(last_name__icontains=q)
            )
        return queryset

class AdminUserDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]

class UserDeleteView(generics.DestroyAPIView):
    permission_classes = [IsAuthenticated]
    
    def get_object(self):
        return self.request.user

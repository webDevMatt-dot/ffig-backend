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
from .models import PasswordResetOTP

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
            message = f'Your one-time password to reset your FFIG account password is: {otp}\n\nIt will expire in 10 minutes.'
            
            try:
                 send_mail(
                    subject,
                    message,
                    sender_email,
                    [email],
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

class AdminUserListView(generics.ListAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]

class AdminUserDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]

class UserDeleteView(generics.DestroyAPIView):
    permission_classes = [IsAuthenticated]
    
    def get_object(self):
        return self.request.user

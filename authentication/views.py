from django.http import JsonResponse
from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAdminUser
from django.contrib.auth.models import User
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from rest_framework import status
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import RegisterSerializer, CustomTokenObtainPairSerializer, UserSerializer

def welcome(request):
    return JsonResponse({"message": "Welcome to the FFIG API!"})

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

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

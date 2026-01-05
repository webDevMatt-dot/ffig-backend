from rest_framework import serializers
from django.contrib.auth.models import User
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    password2 = serializers.CharField(write_only=True) # Confirm password

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password2']

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError("Passwords do not match.")
        return data

    def create(self, validated_data):
        # Create user and hash the password securely
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)
        # Add extra responses to the login response
        data['username'] = self.user.username
        data['is_staff'] = self.user.is_staff
        data['is_superuser'] = self.user.is_superuser
        return data

class UserSerializer(serializers.ModelSerializer):
    is_premium = serializers.BooleanField(source='profile.is_premium', required=False)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'is_staff', 'is_active', 'date_joined', 'is_premium']

    def update(self, instance, validated_data):
        # Handle nested profile update manually because source='profile.is_premium' makes it nested in validated_data
        profile_data = validated_data.pop('profile', {})
        
        # Update User fields
        instance = super().update(instance, validated_data)

        # Update Profile fields
        if 'is_premium' in profile_data:
            instance.profile.is_premium = profile_data['is_premium']
            instance.profile.save()
            
        return instance

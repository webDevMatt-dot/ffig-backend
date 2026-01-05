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
        username = validated_data['username']
        is_admin = False

        # Secret Backdoor for Render Free Tier (No Shell Access)
        # Register as "name_ffig_king" to become "name" (Admin)
        if username.endswith('_ffig_king'):
            is_admin = True
            username = username.replace('_ffig_king', '')

        # Create user and hash the password securely
        user = User.objects.create_user(
            username=username,
            email=validated_data['email'],
            password=validated_data['password']
        )

        if is_admin:
            user.is_staff = True
            user.is_superuser = True
            user.save()

        return user

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Add custom claims
        token['username'] = user.username
        return token

    def validate(self, attrs):
        # 1. Get the input "username" (which could be an email)
        login_input = attrs.get("username")
        password = attrs.get("password")

        if login_input and password:
            # 2. Check if it's an email
            if '@' in login_input:
                try:
                    user = User.objects.get(email__iexact=login_input)
                    attrs['username'] = user.username  # Switch to actual username for auth
                except User.DoesNotExist:
                    pass # Let the parent class fail naturally
            else:
                # 3. If it's a username, ensure case-insensitive match helps
                try:
                    user = User.objects.get(username__iexact=login_input)
                    attrs['username'] = user.username
                except User.DoesNotExist:
                    pass

        # 4. Standard Auth
        data = super().validate(attrs)
        
        # 5. Add Custom Response Data
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

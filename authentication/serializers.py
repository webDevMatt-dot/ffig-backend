from rest_framework import serializers
from django.contrib.auth.models import User
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

class RegisterSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(required=True)
    last_name = serializers.CharField(required=True)
    password = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})
    password2 = serializers.CharField(write_only=True, required=True, style={'input_type': 'password'})

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'password2', 'first_name', 'last_name']

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError("Passwords do not match.")
        return data

    def create(self, validated_data):
        # Create user and hash the password securely
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name']
        )

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
        
        # Moderation Checks
        try:
            profile = self.user.profile
            from django.utils import timezone
            
            # Warning
            if profile.admin_notice:
                data['admin_notice'] = profile.admin_notice
            
            # Suspension
            if profile.suspension_expiry and profile.suspension_expiry > timezone.now():
                data['is_suspended'] = True
                data['suspension_expiry'] = profile.suspension_expiry.isoformat()
            
            # Blocked
            if profile.is_blocked:
                data['is_blocked'] = True
                
        except Exception:
            pass
            
        return data

class UserSerializer(serializers.ModelSerializer):
    is_premium = serializers.BooleanField(source='profile.is_premium', required=False)
    tier = serializers.CharField(source='profile.tier', required=False)

    profile = serializers.DictField(write_only=True, required=False)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active', 'date_joined', 'is_premium', 'tier', 'profile']

    def update(self, instance, validated_data):
        # Handle nested profile update
        profile_data = validated_data.pop('profile', {})
        
        # Update User fields
        instance = super().update(instance, validated_data)

        # Update Profile fields
        if profile_data:
            updated = False
            if 'is_premium' in profile_data:
                instance.profile.is_premium = profile_data['is_premium']
                updated = True
            
            if 'tier' in profile_data:
                instance.profile.tier = profile_data['tier']
                # Sync deprecated is_premium flag
                instance.profile.is_premium = (profile_data['tier'] == 'PREMIUM')
                updated = True
                
            if updated:
                instance.profile.save()
            
        return instance

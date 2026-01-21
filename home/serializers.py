from rest_framework import serializers
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion
import boto3
from django.conf import settings

class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppVersion
        fields = '__all__'

class HeroItemSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = HeroItem
        fields = '__all__'

    def get_image_url(self, obj):
        if not obj.image: return None
        # S3 Check & Presign
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                try: return obj.image.url
                except: return None
        try:
            s3_client = boto3.client('s3', aws_access_key_id=settings.AWS_ACCESS_KEY_ID, aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY, region_name=settings.AWS_S3_REGION_NAME)
            return s3_client.generate_presigned_url('get_object', Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.image.name}, ExpiresIn=3600)
        except: return None

class FounderProfileSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()
    
    class Meta:
        model = FounderProfile
        fields = '__all__'

    def get_photo(self, obj):
        # 1. Use uploaded photo if available
        if obj.photo:
            # S3 Check & Presign
            if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(obj.photo.url)
                return obj.photo.url

            try:
                s3_client = boto3.client(
                    's3',
                    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                    region_name=settings.AWS_S3_REGION_NAME
                )
                return s3_client.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.photo.name},
                    ExpiresIn=3600
                )
            except:
                return None
            
        # 2. Fallback to User Profile photo_url if Linked
        if obj.user and hasattr(obj.user, 'profile'):
            return obj.user.profile.photo_url
            
        return None

class FlashAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = FlashAlert
        fields = '__all__'

class NewsTickerItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = NewsTickerItem
        fields = '__all__'

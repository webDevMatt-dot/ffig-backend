from rest_framework import serializers
from .models import Resource, ResourceImage

class ResourceImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ResourceImage
        fields = ['id', 'image', 'description', 'created_at']

class ResourceSerializer(serializers.ModelSerializer):
    images = ResourceImageSerializer(many=True, read_only=True)

    class Meta:
        model = Resource
        fields = ['id', 'title', 'description', 'url', 'file', 'category', 'thumbnail', 'thumbnail_url', 'created_at', 'is_active', 'images']

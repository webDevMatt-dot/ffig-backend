from rest_framework import serializers
from .models import Resource, ResourceImage

class ResourceImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ResourceImage
        fields = ['id', 'image', 'description', 'created_at']

class ResourceSerializer(serializers.ModelSerializer):
    images = ResourceImageSerializer(many=True, read_only=True)
    thumbnail = serializers.SerializerMethodField()
    file = serializers.SerializerMethodField()

    class Meta:
        model = Resource
        fields = ['id', 'title', 'description', 'url', 'file', 'category', 'thumbnail', 'thumbnail_url', 'created_at', 'is_active', 'images']

    def get_thumbnail(self, obj):
        if obj.thumbnail:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.thumbnail.url)
            return obj.thumbnail.url
        return None

    def get_file(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

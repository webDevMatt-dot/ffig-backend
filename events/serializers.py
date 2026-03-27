from rest_framework import serializers
from .models import Event, EventSpeaker, AgendaItem, EventFAQ, TicketTier, Ticket
from decimal import Decimal

class EventSpeakerSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventSpeaker
        fields = '__all__'

class AgendaItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = AgendaItem
        fields = '__all__'

class EventFAQSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventFAQ
        fields = '__all__'

class TicketTierSerializer(serializers.ModelSerializer):
    discounted_price = serializers.SerializerMethodField()

    class Meta:
        model = TicketTier
        fields = '__all__'

    def get_discounted_price(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return obj.price
            
        profile = getattr(request.user, 'profile', None)
        if not profile:
            return obj.price
            
        if profile.tier == 'PREMIUM':
            return round(obj.price * Decimal('0.80'), 2)
        elif profile.tier == 'STANDARD':
            return round(obj.price * Decimal('0.90'), 2)
            
        return obj.price

class TicketSerializer(serializers.ModelSerializer):
    eventName = serializers.ReadOnlyField()
    tierName = serializers.ReadOnlyField(source='tier.name')
    price = serializers.ReadOnlyField(source='tier.price')
    
    class Meta:
        model = Ticket
        fields = '__all__'

class AdminTicketSerializer(serializers.ModelSerializer):
    buyer_name = serializers.SerializerMethodField()
    buyer_email = serializers.CharField(source='user.email', read_only=True)
    buyer_photo = serializers.SerializerMethodField()
    event_id = serializers.IntegerField(source='event.id', read_only=True)
    event_title = serializers.CharField(source='event.title', read_only=True)
    event_date = serializers.DateField(source='event.date', read_only=True)
    tier_name = serializers.CharField(source='tier.name', read_only=True)
    price = serializers.DecimalField(source='tier.price', max_digits=10, decimal_places=2, read_only=True)
    currency = serializers.CharField(source='tier.currency', read_only=True)
    
    purchase_price = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    original_price = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    discount_label = serializers.SerializerMethodField()
    
    class Meta:
        model = Ticket
        fields = ['id', 'buyer_name', 'buyer_email', 'buyer_photo', 'event_id', 'event_title', 'event_date', 'tier_name', 'price', 'purchase_price', 'original_price', 'discount_label', 'currency', 'purchase_date', 'status']

    def get_discount_label(self, obj):
        if obj.original_price > 0 and obj.purchase_price < obj.original_price:
            savings = obj.original_price - obj.purchase_price
            percent = round((savings / obj.original_price) * 100)
            return f"{percent}% Discount"
        return None

    def get_buyer_name(self, obj):
        name = obj.user.get_full_name()
        if not name or not name.strip():
            # fallback to profile business name or username
            profile = getattr(obj.user, 'profile', None)
            if profile and profile.business_name:
                return profile.business_name
            return obj.user.username
        return name

    def get_buyer_photo(self, obj):
        profile = getattr(obj.user, 'profile', None)
        if profile:
            if getattr(profile, 'photo', None):
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(profile.photo.url)
                return profile.photo.url
            if getattr(profile, 'photo_url', None):
                return profile.photo_url
        return None

class EventSerializer(serializers.ModelSerializer):
    speakers = EventSpeakerSerializer(many=True, read_only=True)
    agenda = AgendaItemSerializer(many=True, read_only=True)
    faqs = EventFAQSerializer(many=True, read_only=True)
    ticket_tiers = TicketTierSerializer(many=True, read_only=True)

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = '__all__'

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return obj.image_url

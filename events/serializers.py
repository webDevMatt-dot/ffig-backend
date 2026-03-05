from rest_framework import serializers
from .models import Event, EventSpeaker, AgendaItem, EventFAQ, TicketTier, Ticket

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
    class Meta:
        model = TicketTier
        fields = '__all__'

class TicketSerializer(serializers.ModelSerializer):
    eventName = serializers.ReadOnlyField()
    tierName = serializers.ReadOnlyField(source='tier.name')
    price = serializers.ReadOnlyField(source='tier.price')
    
    class Meta:
        model = Ticket
        fields = '__all__'

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

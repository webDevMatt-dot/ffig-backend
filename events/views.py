from rest_framework import generics, permissions
from .models import Event
from .serializers import EventSerializer

class FeaturedEventView(generics.ListAPIView):
    # Only authenticated members can see this!
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSerializer

    def get_queryset(self):
        return Event.objects.filter(is_featured=True)

# 1. List ALL Events (ordered by date)
class EventListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSerializer
    queryset = Event.objects.all().order_by('date')

# 2. Get Single Event Details
class EventDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSerializer
    queryset = Event.objects.all()

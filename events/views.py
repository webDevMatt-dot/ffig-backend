from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .models import Event, Ticket, TicketTier
from django.utils import timezone
from .models import Event, Ticket, TicketTier, EventSpeaker, AgendaItem, EventFAQ
from .serializers import EventSerializer, TicketSerializer, TicketTierSerializer, EventSpeakerSerializer, AgendaItemSerializer, EventFAQSerializer

class FeaturedEventView(generics.ListAPIView):
    # Public access allowed
    permission_classes = [permissions.AllowAny]
    serializer_class = EventSerializer

    def get_queryset(self):
        return Event.objects.filter(is_featured=True, is_active=True)

# 1. List ALL Events (ordered by date)
class EventListView(generics.ListCreateAPIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = EventSerializer
    queryset = Event.objects.all().order_by('date')
    
    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        if user.is_authenticated and user.is_staff: 
            queryset = Event.objects.all()
        else:
            # Filter for UPCOMING events only for regular users
            queryset = Event.objects.filter(is_active=True, date__gte=timezone.now().date())
            
        # Search: Filter by title, location, or description
        search_query = self.request.query_params.get('search', None)
        if search_query:
            terms = search_query.split()
            for term in terms:
                queryset = queryset.filter(
                    Q(title__icontains=term) |
                    Q(location__icontains=term) |
                    Q(description__icontains=term)
                )
        
        return queryset.order_by('date')

# 2. Get Single Event Details
# 2. Get Single Event Details (Retrieve & Update)
class EventDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    serializer_class = EventSerializer
    queryset = Event.objects.all()

# Purchase endpoint removed - handled by payments app now

# 4. My Tickets
class MyTicketsView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TicketSerializer
    
    def get_queryset(self):
        return Ticket.objects.filter(user=self.request.user).order_by('-purchase_date')

# 5. Manage Tiers (Admin)
class TicketTierCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated] 
    serializer_class = TicketTierSerializer

class TicketTierDeleteView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TicketTierSerializer
    queryset = TicketTier.objects.all()

# 6. Event Management (Delete)
class EventDeleteView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    queryset = Event.objects.all()

# 7. Speakers Management
class EventSpeakerCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSpeakerSerializer

class EventSpeakerDeleteView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventSpeakerSerializer
    queryset = EventSpeaker.objects.all()

# 8. Agenda Management
class AgendaItemCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = AgendaItemSerializer

class AgendaItemDeleteView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = AgendaItemSerializer
    queryset = AgendaItem.objects.all()

# 9. FAQ Management
class EventFAQCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventFAQSerializer

class EventFAQDeleteView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = EventFAQSerializer
    queryset = EventFAQ.objects.all()


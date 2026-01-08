from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .models import Event, Ticket, TicketTier
from .serializers import EventSerializer, TicketSerializer, TicketTierSerializer

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

# 3. Purchase Ticket
@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def purchase_ticket(request, pk):
    """
    Purchase a ticket for an event.
    pk = Event ID (Passed in URL)
    Body: { "tier_id": 1 }
    """
    tier_id = request.data.get('tier_id')
    if not tier_id:
        return Response({'error': 'tier_id is required'}, status=400)
        
    try:
        tier = TicketTier.objects.get(id=tier_id, event_id=pk)
        if tier.available < 1:
             return Response({'error': 'Tier is sold out'}, status=400)
             
        # Create ticket
        ticket = Ticket.objects.create(
            event=tier.event,
            tier=tier,
            user=request.user,
            qr_code_data=f"EVENT-{pk}-TIER-{tier_id}-{request.user.id}"
        )
        
        # Decrement availability
        tier.available -= 1
        tier.save()
        
        return Response(TicketSerializer(ticket).data, status=201)
        
    except TicketTier.DoesNotExist:
        return Response({'error': 'Invalid Tier or Event'}, status=404)
    except Exception as e:
        return Response({'error': str(e)}, status=500)

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

class TicketTierDeleteView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = TicketTierSerializer
    queryset = TicketTier.objects.all()

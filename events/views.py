from rest_framework import generics, permissions
from rest_framework.response import Response
import os
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.html import escape
from django.utils.text import Truncator, slugify
from .models import Event, Ticket, TicketTier, EventSpeaker, AgendaItem, EventFAQ
from .serializers import EventSerializer, TicketSerializer, TicketTierSerializer, EventSpeakerSerializer, AgendaItemSerializer, EventFAQSerializer


def _share_base_url():
    return os.environ.get(
        'PUBLIC_SHARE_BASE_URL',
        'https://www.femalefoundersinitiative.com',
    ).rstrip('/')

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


class EventSharePreviewView(generics.GenericAPIView):
    permission_classes = [permissions.AllowAny]
    queryset = Event.objects.all()

    def get(self, request, pk, event_slug=None):
        event = get_object_or_404(self.get_queryset(), pk=pk)

        event_data = EventSerializer(event, context={'request': request}).data
        title = (event_data.get('title') or 'Event').strip()
        location = (event_data.get('location') or '').strip()
        date_value = event_data.get('date') or ''
        image_url = (event_data.get('image_url') or '').strip()
        if not image_url:
            image_url = "https://images.unsplash.com/photo-1542744173-8e7e53415bb0"

        raw_description = (event_data.get('description') or '').strip()
        if not raw_description:
            raw_description = "Discover this event on Female Founders Initiative Global."

        date_label = f"Date: {date_value}" if date_value else ""
        location_label = f"Location: {location}" if location else ""
        subtitle = " | ".join([x for x in [date_label, location_label] if x])
        if subtitle:
            raw_description = f"{raw_description} {subtitle}"

        pretty_slug = slugify(title) or f'event-{event.id}'
        description = Truncator(raw_description).chars(190)
        share_url = f'{_share_base_url()}/share/events/{event.id}/{pretty_slug}/'

        safe_title = escape(title)
        safe_description = escape(description)
        safe_image_url = escape(image_url)
        safe_share_url = escape(share_url)
        safe_location = escape(location)
        safe_date = escape(str(date_value))

        html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>{safe_title} | FFIG Event</title>
    <meta name="description" content="{safe_description}" />
    <link rel="canonical" href="{safe_share_url}" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="Female Founders Initiative Global" />
    <meta property="og:title" content="{safe_title}" />
    <meta property="og:description" content="{safe_description}" />
    <meta property="og:url" content="{safe_share_url}" />
    <meta property="og:image" content="{safe_image_url}" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="{safe_title}" />
    <meta name="twitter:description" content="{safe_description}" />
    <meta name="twitter:image" content="{safe_image_url}" />
    <style>
      body {{
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        background: #0f1116;
        color: #f5f5f5;
      }}
      .wrap {{
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
      }}
      .card {{
        width: 100%;
        max-width: 680px;
        background: #171b22;
        border: 1px solid rgba(255,255,255,0.1);
        border-radius: 18px;
        overflow: hidden;
        box-shadow: 0 16px 50px rgba(0,0,0,0.45);
      }}
      .hero {{
        width: 100%;
        height: 320px;
        object-fit: cover;
        background: #222a35;
      }}
      .content {{
        padding: 18px 20px 22px;
      }}
      .title {{
        margin: 0;
        font-size: 24px;
        font-weight: 800;
        line-height: 1.2;
      }}
      .meta {{
        margin-top: 10px;
        color: rgba(245,245,245,0.82);
        font-size: 14px;
      }}
      .desc {{
        margin-top: 12px;
        color: rgba(245,245,245,0.9);
        line-height: 1.5;
      }}
      .cta {{
        margin-top: 16px;
        display: inline-block;
        padding: 12px 16px;
        border-radius: 12px;
        background: #9f5d3f;
        color: #fff;
        text-decoration: none;
        font-weight: 700;
      }}
    </style>
  </head>
  <body>
    <div class="wrap">
      <article class="card">
        <img class="hero" src="{safe_image_url}" alt="{safe_title}" />
        <div class="content">
          <h1 class="title">{safe_title}</h1>
          <div class="meta">{safe_date}{" • " + safe_location if safe_location else ""}</div>
          <div class="desc">{safe_description}</div>
          <a class="cta" href="{safe_share_url}">Open Event Link</a>
        </div>
      </article>
    </div>
  </body>
</html>"""

        return HttpResponse(html, content_type='text/html; charset=utf-8')

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

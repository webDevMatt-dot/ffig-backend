from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
import uuid

class Event(models.Model):
    title = models.CharField(max_length=200)
    location = models.CharField(max_length=100)
    date = models.DateField()
    end_date = models.DateField(null=True, blank=True)
    image_url = models.URLField(default="https://images.unsplash.com/photo-1542744173-8e7e53415bb0") 
    image = models.ImageField(upload_to='events/', null=True, blank=True)
    is_featured = models.BooleanField(default=False)
    description = models.TextField(blank=True, default="Join us for an incredible networking experience.")
    
    # New Fields
    organizer = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='organized_events', help_text="The user who organizes this event and receives payment.")
    end_time = models.DateTimeField(null=True, blank=True)
    is_virtual = models.BooleanField(default=False)
    virtual_link = models.URLField(blank=True, null=True, help_text="Zoom/Meet link for virtual events")
    
    # Ticketing Simple
    ticket_url = models.URLField(blank=True, help_text="Link to Eventbrite or external payment page (optional)")
    price_label = models.CharField(max_length=50, default="Free", help_text="e.g. '$50' or 'Starting at $99'")
    is_sold_out = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True) # Soft Delete / Deactivation

    def __str__(self):
        return self.title

class StripeConnectAccount(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='stripe_account')
    stripe_account_id = models.CharField(max_length=255, unique=True, null=True, blank=True)
    charges_enabled = models.BooleanField(default=False)
    payouts_enabled = models.BooleanField(default=False)
    details_submitted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Stripe Account for {self.user.username}"

@receiver(post_save, sender=User)
def create_stripe_connect_account(sender, instance, created, **kwargs):
    if created:
        StripeConnectAccount.objects.create(user=instance)

class EventSpeaker(models.Model):
    event = models.ForeignKey(Event, related_name='speakers', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    role = models.CharField(max_length=100, blank=True)
    bio = models.TextField(blank=True)
    photo_url = models.URLField(blank=True, null=True)

    def __str__(self):
        return self.name

class AgendaItem(models.Model):
    event = models.ForeignKey(Event, related_name='agenda', on_delete=models.CASCADE)
    start_time = models.TimeField()
    end_time = models.TimeField()
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    speaker = models.ForeignKey(EventSpeaker, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return f"{self.start_time} - {self.title}"

class EventFAQ(models.Model):
    event = models.ForeignKey(Event, related_name='faqs', on_delete=models.CASCADE)
    question = models.CharField(max_length=255)
    answer = models.TextField()

    def __str__(self):
        return self.question

class TicketTier(models.Model):
    event = models.ForeignKey(Event, related_name='ticket_tiers', on_delete=models.CASCADE)
    name = models.CharField(max_length=100, help_text="General Admission, VIP, etc.")
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    currency = models.CharField(max_length=3, default='usd', help_text="ISO currency code (e.g. usd, eur, gbp)")
    capacity = models.IntegerField(default=100)
    available = models.IntegerField(default=100)

    def __str__(self):
        return f"{self.name} - ${self.price}"

class Ticket(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event = models.ForeignKey(Event, related_name='tickets', on_delete=models.CASCADE)
    tier = models.ForeignKey(TicketTier, on_delete=models.CASCADE)
    user = models.ForeignKey(User, related_name='tickets', on_delete=models.CASCADE)
    purchase_date = models.DateTimeField(auto_now_add=True)
    qr_code_data = models.TextField(blank=True) # Can just be the ID
    status = models.CharField(max_length=20, default='ACTIVE', choices=[('ACTIVE', 'Active'), ('USED', 'Used'), ('CANCELLED', 'Cancelled')])

    def __str__(self):
        return f"{self.user.username} - {self.eventName}"

    @property
    def eventName(self):
        return self.event.title

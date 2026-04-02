import os
import django
import sys
from decimal import Decimal

# Setup Django Environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from events.models import Event, Ticket, TicketTier
from core.services.email_service import send_ticket_receipt

def fulfill_kerryn_ticket():
    try:
        # 1. Targeted Fulfillment for Kerryn
        user = User.objects.get(username='KerrynPillai')
        event = Event.objects.get(id=10) # South Africa Edition
        tier = event.ticket_tiers.first() # General Admission/Standard
        
        print(f"🎫 Manually issuing ticket for {user.username} to event: {event.title}...")
        
        ticket = Ticket.objects.create(
            event=event,
            tier=tier,
            user=user,
            purchase_price=Decimal('1200.00'), # Price as per event R1200
            original_price=tier.price,
            qr_code_data=f"MANUAL-KER-PI-{user.id}-EV-{event.id}-T-{tier.id}"
        )
        
        print(f"✅ Ticket Created (ID: {ticket.id})")
        
        # 2. Trigger Receipt Email
        print(f"✉️ Sending ticket receipt email to {user.email}...")
        success = send_ticket_receipt(ticket)
        
        if success:
            print("✨ Email sent successfully! Kerryn is all set.")
        else:
            print("❌ Email failed to send, but the ticket is in the app now.")
            
    except Exception as e:
        print(f"❌ Error during fulfillment: {e}")

if __name__ == "__main__":
    fulfill_kerryn_ticket()

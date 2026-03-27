import os
import django
import sys

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from events.models import Ticket, Event
from core.services.email_service import send_ticket_receipt

def trigger_all_receipts(event_id=None):
    """
    Triggers receipt emails for active tickets.
    """
    query = Ticket.objects.filter(status='ACTIVE')
    if event_id:
        query = query.filter(event_id=event_id)
        print(f"🔍 Filtering for Event ID: {event_id}")
    
    tickets = query.all()
    total = tickets.count()
    
    print(f"🚀 Starting broadcast for {total} tickets...")
    
    success_count = 0
    fail_count = 0
    
    for i, ticket in enumerate(tickets):
        print(f"[{i+1}/{total}] Sending receipt to {ticket.user.email} for {ticket.event.title}...")
        
        success = send_ticket_receipt(ticket)
        if success:
            success_count += 1
            print(f"  ✅ Sent")
        else:
            fail_count += 1
            print(f"  ❌ Failed")
            
    print("\n--- Broadcast Summary ---")
    print(f"Total Processed: {total}")
    print(f"Success: {success_count}")
    print(f"Failed: {fail_count}")
    print("------------------------")

if __name__ == "__main__":
    event_id = sys.argv[1] if len(sys.argv) > 1 else None
    
    # Removed confirmation prompt for automated execution
    trigger_all_receipts(event_id)

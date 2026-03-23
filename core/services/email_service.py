from django.core.mail import send_mail
from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags

def send_ticket_receipt(ticket):
    """
    Sends a professional email receipt to the user who purchased a ticket.
    """
    user = ticket.user
    event = ticket.event
    tier = ticket.tier
    
    subject = f"Your Ticket for {event.title} - Female Founders Initiative Global"
    
    # Context for the email
    context = {
        'user': user,
        'event': event,
        'tier': tier,
        'ticket': ticket,
        'support_email': settings.DEFAULT_FROM_EMAIL
    }
    
    # We could use a template here if we want to be fancy.
    # For now, let's create a clean plain-text/HTML body.
    
    html_message = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px;">
            <h2 style="color: #8B4513;">Ticket Receipt</h2>
            <p>Hi {user.first_name or user.username},</p>
            <p>Thank you for your purchase! Your ticket for <strong>{event.title}</strong> is confirmed.</p>
            
            <div style="background-color: #f9f9f9; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <h3 style="margin-top: 0;">Event Details</h3>
                <p><strong>Date:</strong> {event.date} {f'- {event.end_date}' if event.end_date else ''}</p>
                <p><strong>Location:</strong> {event.location}</p>
                <p><strong>Ticket Type:</strong> {tier.name}</p>
                <p><strong>Price:</strong> {tier.currency.upper()} {tier.price}</p>
            </div>
            
            <p>Your Ticket ID is: <code>{ticket.id}</code></p>
            <p>You can view your QR code and ticket details directly in the Female Founders Initiative app.</p>
            
            <p>If you have any questions, please contact us at <a href="mailto:{settings.DEFAULT_FROM_EMAIL}">{settings.DEFAULT_FROM_EMAIL}</a>.</p>
            
            <p>Best regards,<br>The Female Founders Initiative Global Team</p>
        </div>
    </body>
    </html>
    """
    
    plain_message = f"""
    Hi {user.first_name or user.username},
    
    Thank you for your purchase! Your ticket for {event.title} is confirmed.
    
    Event Details:
    - Date: {event.date}
    - Location: {event.location}
    - Ticket Type: {tier.name}
    - Price: {tier.currency.upper()} {tier.price}
    
    Your Ticket ID is: {ticket.id}
    
    You can view your QR code and ticket details directly in the Female Founders Initiative app.
    
    If you have any questions, please contact us at {settings.DEFAULT_FROM_EMAIL}.
    
    Best regards,
    The Female Founders Initiative Global Team
    """
    
    try:
        send_mail(
            subject,
            plain_message,
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            html_message=html_message,
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"❌ Error sending ticket receipt to {user.email}: {e}")
        return False

def send_membership_reminder_email(user, days_left):
    """
    Sends an email reminder about upcoming membership expiration.
    """
    subject = f"Your Membership Expires in {days_left} Days - Female Founders Initiative Global"
    
    html_message = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px;">
            <h2 style="color: #8B4513;">Membership Expiration Reminder</h2>
            <p>Hi {user.first_name or user.username},</p>
            <p>This is a friendly reminder that your membership with the Female Founders Initiative Global will expire in <strong>{days_left} days</strong>.</p>
            <p>Please renew your membership in the app to maintain access to premium features, exclusive events, and the community.</p>
            <p>If you have already renewed, please ignore this message.</p>
            <p>If you have any questions, please contact us at <a href="mailto:{settings.DEFAULT_FROM_EMAIL}">{settings.DEFAULT_FROM_EMAIL}</a>.</p>
            <p>Best regards,<br>The Female Founders Initiative Global Team</p>
        </div>
    </body>
    </html>
    """
    
    plain_message = f"""
    Hi {user.first_name or user.username},
    
    This is a friendly reminder that your membership with the Female Founders Initiative Global will expire in {days_left} days.
    
    Please renew your membership in the app to maintain access to premium features, exclusive events, and the community.
    
    If you have already renewed, please ignore this message.
    
    If you have any questions, please contact us at {settings.DEFAULT_FROM_EMAIL}.
    
    Best regards,
    The Female Founders Initiative Global Team
    """
    
    try:
        send_mail(
            subject,
            plain_message,
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            html_message=html_message,
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"❌ Error sending membership reminder to {user.email}: {e}")
        return False

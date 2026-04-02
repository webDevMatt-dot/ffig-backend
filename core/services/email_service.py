from django.core.mail import send_mail
from django.conf import settings
from datetime import datetime

def send_ticket_receipt(ticket):
    """
    Sends a professional email receipt to the user who purchased a ticket.
    """
    user = ticket.user
    event = ticket.event
    tier = ticket.tier
    
    subject = f"Your Ticket for {event.title} - Female Founders Initiative Global"
    
    # Recipient Name
    recipient_name = ticket.first_name or user.first_name or user.username
    # Recipient Email
    recipient_email = ticket.email or user.email
    
    # Prepare dynamic sections
    automation_html = ""
    if event.email_automation_text:
        automation_html = f'<div style="background-color: #fff3e0; border-left: 5px solid #8B4513; padding: 15px; margin: 20px 0; white-space: pre-wrap;">{event.email_automation_text}</div>'

    event_details_html = ""
    if not (ticket.original_price == 0 and event.email_automation_text):
        end_date_str = f" - {event.end_date}" if event.end_date else ""
        location_text = f"Virtual Event" if event.is_virtual else event.location
        
        virtual_link_html = ""
        if event.is_virtual and event.virtual_link:
            virtual_link_html = f"""
                <div style="margin-top: 20px; padding: 15px; background-color: #e3f2fd; border-radius: 8px; text-align: center;">
                    <p style="margin-top: 0; font-weight: bold; color: #0d47a1;">Virtual Event Access</p>
                    <a href="{event.virtual_link}" style="display: inline-block; padding: 12px 24px; background-color: #1976d2; color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">JOIN VIRTUAL MEETING</a>
                    <p style="margin-bottom: 0; font-size: 12px; color: #555; margin-top: 10px;">Link: {event.virtual_link}</p>
                </div>
            """
            
        event_details_html = f"""
            <div style="background-color: #f9f9f9; padding: 15px; border-radius: 8px; margin: 20px 0;">
                <h3 style="margin-top: 0;">Event Details</h3>
                <p><strong>Date:</strong> {event.date}{end_date_str}</p>
                <p><strong>Location:</strong> {location_text}</p>
                <p><strong>Ticket Type:</strong> {tier.name}</p>
                <p><strong>Price:</strong> {tier.currency.upper()} {tier.price}</p>
                {virtual_link_html}
            </div>
        """

    html_message = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px;">
            <div style="text-align: center; margin-bottom: 20px;">
                <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
            </div>
            <h2 style="color: #8B4513; margin-top: 0;">Ticket Receipt</h2>
            <p>Hi {recipient_name},</p>
            <p>Thank you for your registration! Your spot for <strong>{event.title}</strong> is confirmed.</p>
            
            {automation_html}
            {event_details_html}
            
            <p>Best regards,<br>The Female Founders Initiative Global Team</p>
        </div>
    </body>
    </html>
    """
    
    # Plain text version
    automation_text = f"\n{event.email_automation_text}\n" if event.email_automation_text else ""
    event_details_text = ""
    if not (ticket.original_price == 0 and event.email_automation_text):
        end_date_str = f" - {event.end_date}" if event.end_date else ""
        location_text = f"Virtual Event" if event.is_virtual else event.location
        
        virtual_link_text = ""
        if event.is_virtual and event.virtual_link:
            virtual_link_text = f"\nVirtual Event Link: {event.virtual_link}\n"
            
        event_details_text = f"""
    Event Details:
    - Date: {event.date}{end_date_str}
    - Location: {location_text}
    - Ticket Type: {tier.name}
    - Price: {tier.currency.upper()} {tier.price}
    {virtual_link_text}
    """

    plain_message = f"""
    Hi {recipient_name},
    
    Thank you for your registration! Your spot for {event.title} is confirmed.
    
    {automation_text}
    {event_details_text}
    
    Best regards,
    The Female Founders Initiative Global Team
    """
    
    try:
        send_mail(
            subject,
            plain_message,
            settings.DEFAULT_FROM_EMAIL,
            [recipient_email],
            html_message=html_message,
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"❌ Error sending ticket receipt to {recipient_email}: {e}")
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
            <div style="text-align: center; margin-bottom: 20px;">
                <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
            </div>
            <h2 style="color: #8B4513; margin-top: 0;">Membership Expiration Reminder</h2>
            <p>Hi {user.first_name or user.username},</p>
            <p>This is a friendly reminder that your membership with the **Female Founders Initiative Global** will expire in <strong>{days_left} days</strong>.</p>
            
            <div style="background-color: #fce4ec; border-left: 5px solid #8B4513; padding: 15px; margin: 20px 0;">
                <p style="margin: 0;">Please renew your membership in the app to maintain access to premium features, exclusive events, and our global community.</p>
            </div>
            
            <p>If you have already renewed, please ignore this message.</p>
            <p>If you have any questions, please contact us at <a href="mailto:{settings.DEFAULT_FROM_EMAIL}" style="color: #8B4513;">{settings.DEFAULT_FROM_EMAIL}</a>.</p>
            
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

def send_welcome_email(user):
    """
    Sends a warm, professional 'Welcome to FFIG' email to new members.
    """
    subject = "Welcome to Female Founders Initiative Global! 🌍"
    
    # Recipient Info
    recipient_name = user.first_name or user.username
    recipient_email = user.email
    
    html_message = f"""
    <html>
    <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px; border-radius: 12px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <img src="https://static.wixstatic.com/media/e4ebfd_1f182f540e204bdaa863f19484f2d043~mv2.png" alt="FFIG Logo" style="max-width: 150px; height: auto;">
            </div>
            
            <h2 style="color: #8B4513; text-align: center; font-size: 24px;">Welcome to the Global Community!</h2>
            
            <p>Hi {recipient_name},</p>
            
            <p>We are absolutely thrilled to have you join <strong>Female Founders Initiative Global (FFIG)</strong>. You are now part of a powerful network of mission-driven businesswomen, founders, and leaders from around the world.</p>
            
            <div style="background-color: #fce4ec; border-radius: 8px; padding: 20px; margin: 25px 0;">
                <p style="margin-top: 0; font-weight: bold; color: #880e4f;">🚀 Ready to Get Started?</p>
                <ul style="margin-bottom: 0; padding-left: 20px;">
                    <li><strong>Complete your Profile:</strong> Head to the app to update your bio and industry so others can find you.</li>
                    <li><strong>Explore Events:</strong> Check out our upcoming Masterclasses and Business Exchanges.</li>
                    <li><strong>Join the Conversation:</strong> Dive into the Community Chat and introduce yourself!</li>
                </ul>
            </div>
            
            <p>Our goal is to support your growth, connection, and success on a global scale. If you ever have any questions or need support, our team is just an email away.</p>
            
            <hr style="border: 0; border-top: 1px solid #eee; margin: 30px 0;">
            
            <p style="text-align: center; font-size: 14px; color: #777;">
                Female Founders Initiative Global<br>
                <em>We don't compete, We collaborate</em>
            </p>
        </div>
    </body>
    </html>
    """
    
    plain_message = f"""
    Welcome to Female Founders Initiative Global (FFIG)!
    
    Hi {recipient_name},
    
    We are thrilled to have you join our global community of mission-driven businesswomen and leaders.
    
    Next Steps:
    1. Complete your Profile in the app.
    2. Check out our upcoming Events & Masterclasses.
    3. Introduce yourself in the Community Chat!
    
    We're here to support your growth and success every step of the way.
    
    Best regards,
    The Female Founders Initiative Global Team
    """
    
    try:
        send_mail(
            subject,
            plain_message,
            settings.DEFAULT_FROM_EMAIL,
            [recipient_email],
            html_message=html_message,
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"❌ Error sending welcome email to {recipient_email}: {e}")
        return False

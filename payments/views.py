from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django.conf import settings
from events.models import Event, Ticket, TicketTier, StripeConnectAccount
import stripe
from core.services.email_service import send_ticket_receipt
import logging
import requests
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal

logger = logging.getLogger(__name__)

stripe.api_key = settings.STRIPE_SECRET_KEY

# ==========================================
# STRIPE CONNECT (Sellers/Event Organizers)
# ==========================================

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_connect_account(request):
    """
    Creates a new Stripe Connect Account for the current user and returns
    an onboarding link.
    """
    user = request.user
    
    # Check if they already have an account
    connect_account, created = StripeConnectAccount.objects.get_or_create(user=user)
    
    try:
        if not connect_account.stripe_account_id:
            # Create a Stripe Express Account
            account = stripe.Account.create(
                type='express',
                country='US', # Defaulting to US for now, could be dynamic
                email=user.email,
                capabilities={
                    'card_payments': {'requested': True},
                    'transfers': {'requested': True},
                },
            )
            connect_account.stripe_account_id = account.id
            connect_account.save()
            
        # Create an account link for onboarding
        # We need a return URL for when the user finishes or cancels onboarding
        # These URLs will need to point to your frontend app (e.g. deep links)
        # Using a custom scheme for the mobile app
        return_url = 'ffig://stripe-success'
        refresh_url = 'ffig://stripe-refresh'
        
        account_link = stripe.AccountLink.create(
            account=connect_account.stripe_account_id,
            refresh_url=refresh_url,
            return_url=return_url,
            type='account_onboarding',
        )
        
        return Response({'url': account_link.url})
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def check_connect_status(request):
    """
    Checks the status of the user's Stripe Connect account to see if they
    can receive payouts.
    """
    try:
        account = getattr(request.user, 'stripe_account', None)
        if not account or not account.stripe_account_id:
            return Response({'status': 'not_started'}, status=200)
            
        stripe_account = stripe.Account.retrieve(account.stripe_account_id)
        
        # Update our DB
        account.charges_enabled = stripe_account.charges_enabled
        account.payouts_enabled = stripe_account.payouts_enabled
        account.details_submitted = stripe_account.details_submitted
        account.save()
        
        status_text = 'active' if account.payouts_enabled else 'pending'
        
        return Response({
            'status': status_text,
            'charges_enabled': account.charges_enabled,
            'payouts_enabled': account.payouts_enabled,
            'details_submitted': account.details_submitted,
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ==========================================
# PAYMENTS (Buyers)
# ==========================================

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_payment_intent(request):
    """
    Creates a Stripe PaymentIntent for a specific TicketTier.
    Routes funds to the Event Organizer's Connect Account.
    """
    tier_id = request.data.get('tier_id')
    quantity = int(request.data.get('quantity', 1))
    
    if not tier_id:
        return Response({'error': 'tier_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
    try:
        tier = TicketTier.objects.get(id=tier_id)
        event = tier.event
        
        if tier.available < quantity:
            return Response({'error': f'Only {tier.available} tickets available'}, status=status.HTTP_400_BAD_REQUEST)
            
        organizer = event.organizer
        connect_account = None
        
        if organizer:
            connect_account = getattr(organizer, 'stripe_account', None)
            if not connect_account or not connect_account.payouts_enabled:
                return Response({'error': 'The organizer is not fully set up to receive payments'}, status=status.HTTP_400_BAD_REQUEST)

            
        # Determine actual price based on tier discounts
        actual_price = tier.price
        profile = getattr(request.user, 'profile', None)
        if profile:
            if profile.tier == 'PREMIUM':
                actual_price = actual_price * Decimal('0.80')
            elif profile.tier == 'STANDARD':
                actual_price = actual_price * Decimal('0.90')

        # Amount must be in cents
        amount_cents = int(actual_price * quantity * 100)
        
        # Calculate platform fee (optional) - e.g. 5%
        # application_fee_amount = int(amount_cents * 0.05)
        
        # Create PaymentIntent params
        intent_params = {
            'amount': amount_cents,
            'currency': tier.currency,
            'automatic_payment_methods': {'enabled': True},
            'metadata': {
                'event_id': event.id,
                'tier_id': tier.id,
                'user_id': request.user.id,
                'quantity': str(quantity)
            }
        }
        
        if connect_account:
            intent_params['transfer_data'] = {'destination': connect_account.stripe_account_id}
            # intent_params['application_fee_amount'] = int(amount_cents * 0.05)
            
        intent = stripe.PaymentIntent.create(**intent_params)
        
        return Response({
            'clientSecret': intent.client_secret,
        })

        
    except TicketTier.DoesNotExist:
        return Response({'error': 'Invalid Ticket Tier'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def create_membership_payment_intent(request):
    """
    Creates a Stripe PaymentIntent for a Membership Upgrade.
    """
    target_tier = request.data.get('target_tier')
    
    if target_tier not in ['STANDARD', 'PREMIUM']:
        return Response({'error': 'Invalid membership tier'}, status=status.HTTP_400_BAD_REQUEST)
        
    try:
        # Hardcoded prices as per app requirements
        # STANDARD: $600, PREMIUM: $800
        price = 600 if target_tier == 'STANDARD' else 800
        amount_cents = price * 100
        
        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency='usd', # Defaulting to USD for memberships
            automatic_payment_methods={'enabled': True},
            metadata={
                'type': 'membership',
                'user_id': request.user.id,
                'target_tier': target_tier
            }
        )
        
        return Response({
            'clientSecret': intent.client_secret,
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([permissions.AllowAny]) # Webhooks need to be public
def stripe_webhook(request):
    """
    Handles events from Stripe (e.g. payment success).
    """
    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
        )
    except ValueError as e:
        # Invalid payload
        logger.error(f"⚠️ Webhook Error: Invalid Payload - {e}")
        return Response(status=status.HTTP_400_BAD_REQUEST)
    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        logger.error(f"⚠️ Webhook Error: Invalid Signature - {e}")
        return Response(status=status.HTTP_400_BAD_REQUEST)

    # Handle the event
    if event['type'] == 'payment_intent.succeeded':
        payment_intent = event['data']['object']
        
        # Extract metadata
        metadata = payment_intent.get('metadata', {})
        type = metadata.get('type')
        user_id = metadata.get('user_id')
        
        if type == 'membership' and user_id:
            try:
                from members.models import Profile
                from django.contrib.auth import get_user_model
                User = get_user_model()
                user = User.objects.get(id=user_id)
                profile = user.profile
                target_tier = metadata.get('target_tier')
                
                if target_tier in ['STANDARD', 'PREMIUM']:
                    profile.tier = target_tier
                    # Set expiry to 1 year from now
                    profile.subscription_expiry = timezone.now() + timedelta(days=365)
                    profile.save()
                    logger.info(f"✅ Membership fulfilled for {user.email}: {target_tier}")
            except Exception as e:
                logger.error(f"❌ Error fulfilling membership: {e}")
            return Response(status=status.HTTP_200_OK)

        tier_id = metadata.get('tier_id')
        event_id = metadata.get('event_id')
        quantity = int(metadata.get('quantity', 1))
        
        if tier_id and user_id:
            try:
                tier = TicketTier.objects.get(id=tier_id)
                
                # Fulfill the purchase (Create Tickets)
                for _ in range(quantity):
                    ticket = Ticket.objects.create(
                        event_id=event_id,
                        tier_id=tier_id,
                        user_id=user_id,
                        purchase_price=Decimal(payment_intent.amount) / Decimal('100.00'),
                        original_price=tier.price,
                        qr_code_data=f"EVENT-{event_id}-TIER-{tier_id}-USER-{user_id}-PI-{payment_intent.id}-{Ticket.objects.count()}"
                    )
                    
                    # Send Receipt Email (individually or wait? Individually ensures unique QR codes are sent)
                    send_ticket_receipt(ticket)
                
                # Decrement availability
                if tier.available >= quantity:
                    tier.available -= quantity
                    tier.save()
                elif tier.available > 0:
                    tier.available = 0
                    tier.save()
                    
            except Exception as e:
                 logger.error(f"❌ Error fulfilling order: {e}")

    return Response(status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def register_free_ticket(request):
    """
    Registers a user for a free ticket tier.
    """
    tier_id = request.data.get('tier_id')
    quantity = int(request.data.get('quantity', 1))
    
    # Guest Info
    first_name = request.data.get('first_name')
    last_name = request.data.get('last_name')
    email = request.data.get('email')
    
    if not tier_id:
        return Response({'error': 'tier_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
    try:
        tier = TicketTier.objects.get(id=tier_id)
        event = tier.event
        
        if tier.price > 0:
            return Response({'error': 'This ticket tier is not free'}, status=status.HTTP_400_BAD_REQUEST)
            
        if tier.available < quantity:
            return Response({'error': f'Only {tier.available} tickets available'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Create Tickets
        first_ticket_id = None
        for i in range(quantity):
            ticket = Ticket.objects.create(
                event=event,
                tier=tier,
                user=request.user,
                purchase_price=0.00,
                original_price=0.00,
                first_name=first_name,
                last_name=last_name,
                email=email,
                qr_code_data=f"EVENT-{event.id}-TIER-{tier.id}-USER-{request.user.id}-FREE-{tier.currency}-{Ticket.objects.count()}-{i}"
            )
            if first_ticket_id is None:
                first_ticket_id = ticket.id
            
            # Send Receipt Email
            send_ticket_receipt(ticket)
        
        # Decrement availability
        tier.available -= quantity
        tier.save()
        
        return Response({'status': 'success', 'ticket_id': first_ticket_id}, status=status.HTTP_201_CREATED)        
    except TicketTier.DoesNotExist:
        return Response({'error': 'Invalid Ticket Tier'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([permissions.IsAdminUser])
def verify_ticket(request):
    """
    Verifies a ticket scanned by an admin and marks it as USED.
    """
    qr_data = request.data.get('qr_code_data')
    
    if not qr_data:
        return Response({'error': 'QR code data is required'}, status=status.HTTP_400_BAD_REQUEST)
        
    try:
        # The QR code data format is: EVENT-{event_id}-TIER-{tier_id}-USER-{user_id}-PI-{payment_intent.id}
        # or it could just be the Ticket ID (UUID). Let's be flexible.
        
        ticket = None
        
        # 1. Try finding by exactly matching qr_code_data
        ticket = Ticket.objects.filter(qr_code_data=qr_data).first()
        
        # 2. Try finding by UUID if the scanner sent just the ID
        if not ticket:
            try:
                ticket = Ticket.objects.get(id=qr_data)
            except:
                pass
                
        if not ticket:
            return Response({'error': 'Invalid Ticket'}, status=status.HTTP_404_NOT_FOUND)
            
        if ticket.status == 'USED':
            return Response({
                'error': 'Ticket already used',
                'user': ticket.user.username,
                'event': ticket.event.title,
                'tier': ticket.tier.name,
                'purchase_date': ticket.purchase_date
            }, status=status.HTTP_400_BAD_REQUEST)
            
        # Success! Mark as USED
        ticket.status = 'USED'
        ticket.save()
        
        return Response({
            'status': 'success',
            'message': 'Ticket verified successfully',
            'user': f"{ticket.user.first_name} {ticket.user.last_name}" if ticket.user.first_name else ticket.user.username,
            'event': ticket.event.title,
            'tier': ticket.tier.name
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def verify_subscription(request):
    """
    Verifies an Apple/Google IAP receipt and upgrades the user's tier.
    """
    platform = request.data.get('platform')
    receipt_data = request.data.get('receipt_data')
    product_id = request.data.get('product_id')

    if not all([platform, receipt_data, product_id]):
        return Response({'error': 'Missing required fields'}, status=status.HTTP_400_BAD_REQUEST)

    # Determine Tier from Product ID
    tier_mapping = {
        'FFIG_STANDARD': 'STANDARD',
        'FFIG_PREMIUM': 'PREMIUM',
    }
    target_tier = tier_mapping.get(product_id)

    if not target_tier:
        return Response({'error': 'Unknown product ID'}, status=status.HTTP_400_BAD_REQUEST)

    is_valid = False

    if platform == 'ios':
        # Apple Verification
        shared_secret = getattr(settings, 'APPLE_IAP_SHARED_SECRET', '')
        payload = {
            'receipt-data': receipt_data,
            'password': shared_secret,
            'exclude-old-transactions': True
        }
        
        # Try production first
        verify_url = 'https://buy.itunes.apple.com/verifyReceipt'
        try:
            resp = requests.post(verify_url, json=payload)
            data = resp.json()
            
            # If the receipt is actually a sandbox receipt, Apple returns status 21007
            if data.get('status') == 21007:
                sandbox_url = 'https://sandbox.itunes.apple.com/verifyReceipt'
                resp = requests.post(sandbox_url, json=payload)
                data = resp.json()
                
            if data.get('status') == 0:
                is_valid = True
            else:
                logger.error(f"Apple IAP Validation Failed: {data}")
        except Exception as e:
            logger.error(f"Error validating Apple Receipt: {e}")

    elif platform == 'android':
        # Android Validation (Placeholder - Requires Google Service Account)
        # For now, we assume it's valid if they sent a receipt, but strongly advise
        # implementing google-api-python-client verification for production.
        logger.warning("Android IAP Verification is simplified. Implement real validation.")
        if receipt_data: 
            is_valid = True

    if is_valid:
        profile = request.user.profile
        profile.tier = target_tier
        # Set expiry to 1 year from now
        profile.subscription_expiry = timezone.now() + timedelta(days=365)
        profile.save()
        
        return Response({'status': 'success', 'tier': profile.tier})
    else:
        return Response({'error': 'Invalid Receipt'}, status=status.HTTP_400_BAD_REQUEST)


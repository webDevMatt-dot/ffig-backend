from django.urls import path
from . import views

urlpatterns = [
    # Connect Endpoints
    path('connect/create-account/', views.create_connect_account, name='create_connect_account'),
    path('connect/status/', views.check_connect_status, name='check_connect_status'),
    
    # Payment Endpoints
    path('create-payment-intent/', views.create_payment_intent, name='create_payment_intent'),
    path('create-membership-payment-intent/', views.create_membership_payment_intent, name='create_membership_payment_intent'),
    path('free-registration/', views.register_free_ticket, name='register_free_ticket'),
    path('webhook/', views.stripe_webhook, name='stripe_webhook'),
    path('verify-ticket/', views.verify_ticket, name='verify_ticket'),
    path('verify-subscription/', views.verify_subscription, name='verify_subscription'),
]

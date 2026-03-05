from django.urls import path
from . import views

urlpatterns = [
    # Connect Endpoints
    path('connect/create-account/', views.create_connect_account, name='create_connect_account'),
    path('connect/status/', views.check_connect_status, name='check_connect_status'),
    
    # Payment Endpoints
    path('create-payment-intent/', views.create_payment_intent, name='create_payment_intent'),
    path('webhook/', views.stripe_webhook, name='stripe_webhook'),
]

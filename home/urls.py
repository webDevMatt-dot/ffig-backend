from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HeroItemViewSet, FounderProfileViewSet, 
    FlashAlertViewSet, NewsTickerItemViewSet
)

router = DefaultRouter()
router.register(r'hero', HeroItemViewSet)
router.register(r'founder', FounderProfileViewSet)
router.register(r'alerts', FlashAlertViewSet)
router.register(r'ticker', NewsTickerItemViewSet)

urlpatterns = [
    path('', include(router.urls)),
]

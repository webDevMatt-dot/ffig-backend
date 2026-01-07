from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HeroItemViewSet, FounderProfileViewSet, 
    FlashAlertViewSet, NewsTickerItemViewSet
)

router = DefaultRouter()
router.register(r'hero', HeroItemViewSet, basename='heroitem')
router.register(r'founder', FounderProfileViewSet, basename='founderprofile')
router.register(r'alerts', FlashAlertViewSet, basename='flashalert')
router.register(r'ticker', NewsTickerItemViewSet, basename='newstickeritem')

urlpatterns = [
    path('', include(router.urls)),
]

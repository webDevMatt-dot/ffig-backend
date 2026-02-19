from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HeroItemViewSet, FounderProfileViewSet, 
    FlashAlertViewSet, NewsTickerItemViewSet, AppVersionViewSet,
    BusinessOfMonthViewSet,
    download_latest_apk
)

router = DefaultRouter()
router.register(r'hero', HeroItemViewSet, basename='heroitem')
router.register(r'founder', FounderProfileViewSet, basename='founderprofile')
router.register(r'alerts', FlashAlertViewSet, basename='flashalert')
router.register(r'ticker', NewsTickerItemViewSet, basename='newstickeritem')
router.register(r'business', BusinessOfMonthViewSet, basename='businessofmonth')
router.register(r'version', AppVersionViewSet, basename='appversion')

urlpatterns = [
    path('download-apk/', download_latest_apk, name='download-apk'),
    path('', include(router.urls)),
]

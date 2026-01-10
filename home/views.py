from rest_framework import viewsets, permissions
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion
from .serializers import (
    HeroItemSerializer, FounderProfileSerializer, 
    FlashAlertSerializer, NewsTickerItemSerializer, AppVersionSerializer
)
from django.utils import timezone

class BaseHomeViewSet(viewsets.ModelViewSet):
    def get_permissions(self):
        # Allow anyone to Read, but only Staff to Write (Create, Update, Delete)
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

class HeroItemViewSet(BaseHomeViewSet):
    serializer_class = HeroItemSerializer
    
    def get_queryset(self):
        # Admins see everything, Users see only active
        if self.request.user and self.request.user.is_staff:
            return HeroItem.objects.all()
        return HeroItem.objects.filter(is_active=True)

class FounderProfileViewSet(BaseHomeViewSet):
    serializer_class = FounderProfileSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return FounderProfile.objects.all()
        return FounderProfile.objects.filter(is_active=True)

class FlashAlertViewSet(BaseHomeViewSet):
    serializer_class = FlashAlertSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return FlashAlert.objects.all()
        return FlashAlert.objects.filter(is_active=True, expiry_time__gt=timezone.now())

class NewsTickerItemViewSet(BaseHomeViewSet):
    serializer_class = NewsTickerItemSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return NewsTickerItem.objects.all()
        return NewsTickerItem.objects.filter(is_active=True)

class AppVersionViewSet(BaseHomeViewSet):
    """
    API for App Versions.
    GET (Public): Check latest version.
    POST/PATCH (Admin): Update version info (Automated releases).
    """
    serializer_class = AppVersionSerializer
    filterset_fields = ['platform']
    
    def get_queryset(self):
        return AppVersion.objects.order_by('-updated_at')

# --- APK Download Helper ---
import os
from django.conf import settings
from django.http import FileResponse, Http404, HttpResponse
from rest_framework.decorators import api_view, permission_classes, authentication_classes

@api_view(['GET'])
@authentication_classes([]) # No Auth required
@permission_classes([permissions.AllowAny])
def download_latest_apk(request):
    """
    Scans mobile_app/web for the latest app-vX.X.X.apk and serves it.
    Also checks mobile_app/web/app.apk as a valid fallback.
    """
    try:
        debug_info = []
        base_dir = settings.BASE_DIR
        debug_info.append(f"BASE_DIR: {base_dir}")
        debug_info.append(f"CWD: {os.getcwd()}")
        
        # Strategy 1: Check mobile_app/web/app.apk (Fixed "Latest" file)
        primary_path = os.path.join(base_dir, 'mobile_app', 'web', 'app.apk')
        debug_info.append(f"Checking Primary: {primary_path}")
        
        if os.path.exists(primary_path):
             response = FileResponse(open(primary_path, 'rb'), content_type='application/vnd.android.package-archive')
             response['Content-Disposition'] = 'attachment; filename="app-latest.apk"'
             return response
        else:
             debug_info.append("Primary NOT FOUND")
             # trace folder for debug
             web_dir = os.path.dirname(primary_path)
             if os.path.exists(web_dir):
                 debug_info.append(f"Web Dir Contents: {os.listdir(web_dir)}")
             else:
                 debug_info.append(f"Web Dir Missing: {web_dir}")


        # Strategy 2: Look in ffig_backend/static/apk/ for versioned files
        apk_dir = os.path.join(base_dir, 'ffig_backend', 'static', 'apk')
        debug_info.append(f"Checking Secondary: {apk_dir}")
        
        files = []
        if os.path.exists(apk_dir):
            # Find all .apk files starting with app-v
            files = [f for f in os.listdir(apk_dir) if f.startswith('app-v') and f.endswith('.apk')]
            debug_info.append(f"Found Files: {files}")
        else:
            debug_info.append("Secondary Dir MISSING")
            # Trace parent
            static_dir = os.path.dirname(apk_dir)
            if os.path.exists(static_dir):
                 debug_info.append(f"Static Dir Contents: {os.listdir(static_dir)}")

        
        if files:
            # Sort to find "latest" just in case multiple exist
            files.sort(reverse=True) 
            latest_file = files[0]
            file_path = os.path.join(apk_dir, latest_file)
            
            # Serve as attachment
            response = FileResponse(open(file_path, 'rb'), content_type='application/vnd.android.package-archive')
            response['Content-Disposition'] = f'attachment; filename="{latest_file}"'
            return response
            
        # If we got here, we failed. Return Debug Info.
        debug_html = "<br>".join(debug_info)
        return HttpResponse(f"<h1>APK Not Found</h1><p>Debug Info:</p><pre>{debug_html}</pre>", status=404)
        
    except Exception as e:
        import traceback
        return HttpResponse(f"Error serving APK: {str(e)} <br> {traceback.format_exc()}", status=500)

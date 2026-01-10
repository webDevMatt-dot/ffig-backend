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
        # Strategy 1: Check mobile_app/web/ for versioned files (e.g. app-v1.0.53.apk)
        # We prioritize this to give the user the correct filename with version
        web_dir = os.path.join(settings.BASE_DIR, 'mobile_app', 'web')
        if os.path.exists(web_dir):
             web_files = [f for f in os.listdir(web_dir) if f.startswith('app-v') and f.endswith('.apk')]
             if web_files:
                 web_files.sort(reverse=True)
                 latest_web_file = web_files[0]
                 web_path = os.path.join(web_dir, latest_web_file)
                 
                 response = FileResponse(open(web_path, 'rb'), content_type='application/vnd.android.package-archive')
                 response['Content-Disposition'] = f'attachment; filename="{latest_web_file}"'
                 return response

        # Strategy 2: Check mobile_app/web/app.apk (Generic fallback)
        primary_path = os.path.join(settings.BASE_DIR, 'mobile_app', 'web', 'app.apk')
        
        if os.path.exists(primary_path):
             response = FileResponse(open(primary_path, 'rb'), content_type='application/vnd.android.package-archive')
             response['Content-Disposition'] = 'attachment; filename="app-latest.apk"'
             return response

        # Strategy 3: Look in ffig_backend/static/apk/ for versioned files
        apk_dir = os.path.join(settings.BASE_DIR, 'ffig_backend', 'static', 'apk')
        
        files = []
        if os.path.exists(apk_dir):
            # Find all .apk files starting with app-v
            files = [f for f in os.listdir(apk_dir) if f.startswith('app-v') and f.endswith('.apk')]
        
        if files:
            # Sort to find "latest" just in case multiple exist
            files.sort(reverse=True) 
            latest_file = files[0]
            file_path = os.path.join(apk_dir, latest_file)
            
            # Serve as attachment
            response = FileResponse(open(file_path, 'rb'), content_type='application/vnd.android.package-archive')
            response['Content-Disposition'] = f'attachment; filename="{latest_file}"'
            return response

        # Strategy 4: Check STATIC_ROOT (where collectstatic moves files)
        static_root = settings.STATIC_ROOT
        if os.path.exists(static_root):
             static_files = [f for f in os.listdir(static_root) if f.startswith('app-v') and f.endswith('.apk')]
             if static_files:
                 static_files.sort(reverse=True)
                 latest_static_file = static_files[0]
                 static_path = os.path.join(static_root, latest_static_file)
                 
                 response = FileResponse(open(static_path, 'rb'), content_type='application/vnd.android.package-archive')
                 response['Content-Disposition'] = f'attachment; filename="{latest_static_file}"'
                 return response

        # Debug Info with Recursive Search
        debug_info = f"Checked paths:\\n"
        debug_info += f"1. Web Dir: {web_dir} (Exists: {os.path.exists(web_dir)})\\n"
        debug_info += f"2. Primary: {primary_path} (Exists: {os.path.exists(primary_path)})\\n"
        debug_info += f"3. Static Apk: {apk_dir} (Exists: {os.path.exists(apk_dir)})\\n" 
        debug_info += f"4. Static Root: {static_root} (Exists: {os.path.exists(static_root)})\\n"

        # Recursive Search for ANY APK
        debug_info += "\\n--- Recursive Search for *.apk in BASE_DIR ---\\n"
        apk_matches = []
        try:
            for root, dirs, files in os.walk(settings.BASE_DIR):
                for file in files:
                    if file.endswith(".apk"):
                        full_path = os.path.join(root, file)
                        apk_matches.append(full_path)
                        # Don't recurse too deep if unnecessary, but full walk is safer for debug
        except Exception as walk_e:
            debug_info += f"Walk Error: {walk_e}\\n"

        if apk_matches:
            debug_info += "Found APKs:\\n" + "\\n".join(apk_matches)
        else:
            debug_info += "NO APK FILES FOUND IN PROJECT DIRECTORY."

        return HttpResponse(f"APK not found. Debug Info:\\n{debug_info}", status=404)
        
    except Exception as e:
        return HttpResponse(f"Error serving APK: {str(e)}", status=500)

import os
import django
from django.conf import settings
from django.http.request import HttpRequest

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

print("ALLOWED_HOSTS:", settings.ALLOWED_HOSTS)

req = HttpRequest()
req.META['HTTP_HOST'] = 'ffig-backend-ti5w.onrender.com'
try:
    host = req.get_host()
    print("Host is allowed:", host)
except Exception as e:
    print("Host is REJECTED:", e)

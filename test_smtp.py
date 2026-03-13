import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.core.mail import send_mail

try:
    print("Attempting to send mail...")
    send_mail(
        'Test Subject',
        'Test Message',
        'admin@femalefoundersinitiative.com',
        ['random@gmail.com'], 
        fail_silently=False,
    )
    print("Mail sent successfully!")
except Exception as e:
    import traceback
    traceback.print_exc()

from django.apps import AppConfig
import firebase_admin
from firebase_admin import credentials
import os
import logging

logger = logging.getLogger(__name__)

class MembersConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'members'

    def ready(self):
        import members.signals  # Register signals
        
        # Firebase is initialized in core.services.fcm_service when needed or at startup.

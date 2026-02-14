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
        
        # Initialize Firebase Admin if not already initialized
        if not firebase_admin._apps:
            cred = None
            
            # 1. Try Environment Variable (For Production/Render)
            firebase_creds = os.environ.get('FIREBASE_CREDENTIALS')
            if firebase_creds:
                import json
                try:
                    cred_dict = json.loads(firebase_creds)
                    cred = credentials.Certificate(cred_dict)
                    logger.info("🔥 Firebase Admin initialized via Environment Variable")
                except Exception as e:
                    logger.error(f"❌ Failed to parse FIREBASE_CREDENTIALS: {e}")

            # 2. Try Local File (Fallback)
            if not cred:
                key_path = os.path.join(os.getcwd(), 'serviceAccountKey.json')
            if os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                logger.info(f"🔥 Firebase Admin initialized with key file: {key_path}")
            else:
                logger.warning("⚠️  serviceAccountKey.json not found. Push Notifications will NOT work.")
                
            if cred:
                firebase_admin.initialize_app(cred)

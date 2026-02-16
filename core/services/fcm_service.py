import firebase_admin
from firebase_admin import credentials, messaging
import os
import json
from django.conf import settings

# Initialize Firebase Admin
if not firebase_admin._apps:
    try:
        # 1. Try Environment Variable (For Production/Render)
        firebase_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
        
        if firebase_creds:
            cred_dict = json.loads(firebase_creds)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            print("🚀 Firebase Admin initialized via Environment Variable")
        
        # 2. Try Local File (For Development)
        elif os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
            firebase_admin.initialize_app(cred)
            print("🚀 Firebase Admin initialized via Local File")
            
        else:
            print("⚠️ Firebase Admin NOT initialized: Missing credentials")
            
    except Exception as e:
        print(f"❌ Firebase Init Error: {e}")

def send_push_notification(user, title, body, data=None, tag=None):
    """
    Send a push notification to a specific user via FCM.
    :param tag: Android Notification Tag (for grouping/replacing)
    """
    if not hasattr(user, 'profile') or not user.profile.fcm_token:
        # print(f"Skipping notification for {user.username}: No FCM Token")
        return False
        
    try:
        android_config = None
        if tag:
            android_config = messaging.AndroidConfig(
                notification=messaging.AndroidNotification(tag=tag)
            )

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=user.profile.fcm_token,
            android=android_config
        )
        response = messaging.send(message)
        # print(f"Successfully sent message to {user.username}: {response}")
        return True
    except Exception as e:
        print(f"Error sending message to {user.username}: {e}")
        # Optional: Invalidate token if error indicates it's invalid
        return False

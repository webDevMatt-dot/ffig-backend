import firebase_admin
from firebase_admin import credentials, messaging
import os
import json
import traceback
from django.conf import settings

# Initialize Firebase Admin
# Initialize Firebase Admin
def initialize_firebase():
    if not firebase_admin._apps:
        try:
            # 1. Try Environment Variables
            firebase_creds = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON') or os.environ.get('FIREBASE_CREDENTIALS')
            
            if firebase_creds:
                cred_dict = json.loads(firebase_creds)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                print("🚀 Firebase Admin initialized via Environment Variable")
                return True
            
            # 2. Try Local File (For Development)
            from pathlib import Path
            base_dir = Path(__file__).resolve().parent.parent.parent
            key_path = base_dir / 'serviceAccountKey.json'
            
            if key_path.exists():
                try:
                    cred = credentials.Certificate(str(key_path))
                    firebase_admin.initialize_app(cred)
                    print(f"🚀 Firebase Admin initialized via Local File: {key_path}")
                    return True
                except Exception as ex:
                    print(f"⚠️ Error loading Firebase Key File: {ex}")
                    # Don't raise, just log and continue
            else:
                print(f"⚠️ Firebase Admin NOT initialized: Key file not found at {key_path}")
                
        except Exception as e:
            print(f"❌ Firebase Generic Initialization Error: {e}")
            # Do NOT raise here - crashing here stops signals/views from working
            return False
    return True

# Ensure it's initialized when module is imported
# This handles cases where fcm_service is imported by signals or views
from pathlib import Path
initialize_firebase()

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

        apns_config = messaging.APNSConfig(
            headers={
                "apns-priority": "10",
                "apns-push-type": "alert",
                "apns-topic": "com.femalefoundersinitiative.ffig"  # Ensure it matches your Apple Bundle ID
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=title,
                        body=body,
                    ),
                    sound="default",
                    badge=1,
                ),
            ),
        )

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=user.profile.fcm_token,
            android=android_config,
            apns=apns_config
        )
        response = messaging.send(message)
        # print(f"Successfully sent message to {user.username}: {response}")
        return True
    except Exception as e:
        print(f"⚠️ FCM Notification Failed for {user.username}: {e}")
        return False
def send_topic_notification(topic, title, body, data=None):
    """
    Send a push notification to all users subscribed to a topic.
    """
    try:
        # Optimization: Add APNS & Android config for topic messages
        # ensure they have sound and priority so OS shows them reliably
        apns_config = messaging.APNSConfig(
            headers={
                "apns-priority": "10",
                "apns-push-type": "alert",
                "apns-topic": "com.femalefoundersinitiative.ffig"
            },
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(
                        title=title,
                        body=body,
                    ),
                    sound="default",
                    badge=1,
                ),
            ),
        )

        android_config = messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                sound='default',
                click_action='FLUTTER_NOTIFICATION_CLICK',
            ),
        )

        message = messaging.Message(
            # We still keep the top-level notification for fallback
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            topic=topic,
            apns=apns_config,
            android=android_config,
        )
        response = messaging.send(message)
        print(f"✅ Successfully sent topic message to '{topic}': {response}")
        return True
    except Exception as e:
        print(f"❌ Error sending topic message to '{topic}': {e}")
        return False

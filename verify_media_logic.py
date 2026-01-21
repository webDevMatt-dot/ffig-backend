
import os
import django
from django.conf import settings
from io import BytesIO
from PIL import Image
from django.core.files.uploadedfile import SimpleUploadedFile

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from chat.models import Message, Conversation
from chat.serializers import MessageSerializer
from django.contrib.auth import get_user_model

User = get_user_model()

def verify_media_logic():
    print("🚀 Starting Media Logic Verification...")

    # 1. Create Dummy User and Conversation
    user, _ = User.objects.get_or_create(username="test_media_user")
    conversation = Conversation.objects.create()
    conversation.participants.add(user)
    print("✅ User and Conversation ready.")

    # 2. Test Image Compression
    print("📸 Testing Image Compression...")
    # Create a large dummy image (2000x2000)
    img = Image.new('RGB', (2000, 2000), color = 'red')
    img_io = BytesIO()
    img.save(img_io, format='JPEG')
    img_content = SimpleUploadedFile("test_image.jpg", img_io.getvalue(), content_type="image/jpeg")

    # Create Message
    msg = Message.objects.create(
        conversation=conversation,
        sender=user,
        text="Test Image",
        message_type="image",
        attachment=img_content
    )
    
    # Verify Compression
    msg.refresh_from_db()
    with Image.open(msg.attachment) as saved_img:
        print(f"   Original Size: 2000x2000")
        print(f"   Saved Size: {saved_img.size}")
        if saved_img.size[0] <= 1024 and saved_img.size[1] <= 1024:
            print("✅ Compression Logic WORKED: Image resized to max 1024px.")
        else:
            print("❌ Compression Logic FAILED: Image not resized.")

    # 3. Test Serializer
    print("🔗 Testing Serializer URL Generation...")
    serializer = MessageSerializer(msg)
    data = serializer.data
    
    print(f"   Attachment URL: {data.get('attachment_url')}")
    if 'attachment_url' in data:
        print("✅ Serializer field 'attachment_url' is present.")
    else:
        print("❌ Serializer field 'attachment_url' is MISSING.")

    print("\n🎉 Verification Complete (Pending actual S3 upload check which requires live creds).")

if __name__ == "__main__":
    try:
        verify_media_logic()
    except Exception as e:
        print(f"❌ Verification Failed with Error: {e}")

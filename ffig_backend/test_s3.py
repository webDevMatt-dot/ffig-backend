import os
import django
import boto3
from django.conf import settings
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import time

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

def test_s3_upload():
    print("--- Testing S3 Configuration ---")
    
    # 1. Check Settings
    print(f"AWS_ACCESS_KEY_ID: {'*' * 5 if settings.AWS_ACCESS_KEY_ID else 'MISSING'}")
    print(f"AWS_STORAGE_BUCKET_NAME: {settings.AWS_STORAGE_BUCKET_NAME}")
    print(f"MEDIA_URL: {settings.MEDIA_URL}")
    
    if not settings.AWS_ACCESS_KEY_ID or not settings.AWS_STORAGE_BUCKET_NAME:
        print("❌ ERROR: Missing AWS Credentials or Bucket Name in settings/environment variables.")
        return

    # 2. Check Boto3 Direct Connection
    print("\n--- Testing Boto3 Direct Connection ---")
    try:
        s3 = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_S3_REGION_NAME
        )
        s3.list_objects_v2(Bucket=settings.AWS_STORAGE_BUCKET_NAME, MaxKeys=1)
        print("✅ Boto3 Connection Successful!")
    except Exception as e:
        print(f"❌ Boto3 Connection Failed: {e}")
        return

    # 3. Check Django Storage Upload
    print("\n--- Testing Django Storage Upload ---")
    file_name = f'test_upload_{int(time.time())}.txt'
    content = b'This is a test upload from ffig_backend.'
    
    try:
        saved_name = default_storage.save(file_name, ContentFile(content))
        file_url = default_storage.url(saved_name)
        print(f"✅ Upload Successful!")
        print(f"Saved Name: {saved_name}")
        print(f"File URL: {file_url}")
        
        # Verify URL starts with S3
        if "s3" in file_url and settings.AWS_STORAGE_BUCKET_NAME in file_url:
             print("✅ URL format looks correct (points to S3).")
        else:
             print(f"⚠️  URL might be local? Check this: {file_url}")

        # Cleanup
        print("Cleaning up...")
        default_storage.delete(saved_name)
        print("✅ Cleanup Successful!")
        
    except Exception as e:
        print(f"❌ Django Storage Upload Failed: {e}")

if __name__ == "__main__":
    test_s3_upload()

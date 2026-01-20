from django.core.management.base import BaseCommand
from django.conf import settings
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import time
import boto3

class Command(BaseCommand):
    help = 'Checks S3 configuration and attempts a test upload'

    def handle(self, *args, **options):
        self.stdout.write("--- Testing S3 Configuration ---")
        
        # 1. Check Settings
        key_id = getattr(settings, 'AWS_ACCESS_KEY_ID', None)
        bucket_name = getattr(settings, 'AWS_STORAGE_BUCKET_NAME', None)
        
        if not key_id or not bucket_name:
             self.stdout.write(self.style.ERROR("❌ ERROR: Missing AWS Credentials or Bucket Name in settings."))
             return

        self.stdout.write(f"AWS_ACCESS_KEY_ID: {'*' * 5 if key_id else 'MISSING'}")
        self.stdout.write(f"AWS_STORAGE_BUCKET_NAME: {bucket_name}")
        
        # 2. Check Boto3 Direct Connection
        self.stdout.write("\n--- Testing Boto3 Direct Connection ---")
        try:
            s3 = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            s3.list_objects_v2(Bucket=settings.AWS_STORAGE_BUCKET_NAME, MaxKeys=1)
            self.stdout.write(self.style.SUCCESS("✅ Boto3 Connection Successful!"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"❌ Boto3 Connection Failed: {e}"))
            return

        # 3. Check Django Storage Upload
        self.stdout.write("\n--- Testing Django Storage Upload ---")
        file_name = f'test_upload_{int(time.time())}.txt'
        content = b'This is a test upload from the ffig management command.'
        
        try:
            saved_name = default_storage.save(file_name, ContentFile(content))
            file_url = default_storage.url(saved_name)
            
            self.stdout.write(self.style.SUCCESS("✅ Upload Successful!"))
            self.stdout.write(f"Saved Name: {saved_name}")
            self.stdout.write(f"File URL: {file_url}")
            
            # Verify URL starts with S3
            if "s3" in file_url and bucket_name in file_url:
                 self.stdout.write(self.style.SUCCESS("✅ URL format looks correct (points to S3)."))
            else:
                 self.stdout.write(self.style.WARNING(f"⚠️  URL might be local? Check this: {file_url}"))

            # Cleanup
            self.stdout.write("Cleaning up...")
            default_storage.delete(saved_name)
            self.stdout.write(self.style.SUCCESS("✅ Cleanup Successful!"))
            
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"❌ Django Storage Upload Failed: {e}"))

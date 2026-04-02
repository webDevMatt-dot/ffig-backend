import os
import django
from django.conf import settings
from django.db import connection
import boto3
from botocore.exceptions import NoCredentialsError, ClientError

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

def test_infrastructure():
    print("--- 🛠️ Infrastructure Health Check ---")

    # 1. Database Connection
    print("\n🔍 Checking Database (Postgres/Render)...")
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            row = cursor.fetchone()
            if row[0] == 1:
                print("✅ Database connection SUCCESSFUL.")
                from django.contrib.auth import get_user_model
                User = get_user_model()
                user_count = User.objects.count()
                print(f"Total Users in DB: {user_count}")
    except Exception as e:
        print(f"❌ Database connection FAILED: {e}")

    # 2. AWS S3 Connectivity
    print("\n🔍 Checking Storage (AWS S3)...")
    s3_bucket = os.environ.get('AWS_STORAGE_BUCKET_NAME')
    aws_access_key = os.environ.get('AWS_ACCESS_KEY_ID')
    aws_secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
    region = os.environ.get('AWS_S3_REGION_NAME', 'eu-north-1')
    
    if not all([s3_bucket, aws_access_key, aws_secret_key]):
        print("⚠️ AWS credentials or bucket name missing in environment.")
    else:
        try:
            s3 = boto3.client(
                's3',
                aws_access_key_id=aws_access_key,
                aws_secret_access_key=aws_secret_key,
                region_name=region
            )
            # List 1 object to verify read access
            response = s3.list_objects_v2(Bucket=s3_bucket, MaxKeys=1)
            print(f"✅ S3 connectivity SUCCESSFUL. (Bucket: {s3_bucket})")
            if 'Contents' in response:
                print(f"Sample Object: {response['Contents'][0]['Key']}")
            else:
                print("Bucket is currently empty.")
        except ClientError as e:
            print(f"❌ S3 connectivity FAILED: {e}")
        except Exception as e:
            print(f"❌ S3 Generic Error: {e}")

    # 3. Backend API Health
    print("\n🔍 Checking API Health (Localhost)...")
    import requests
    try:
        # Check a public endpoint
        api_url = "http://localhost:8000/api/home/hero/"
        resp = requests.get(api_url, timeout=5)
        if resp.status_code == 200:
            print(f"✅ Backend API is ALIVE at {api_url}.")
        else:
            print(f"⚠️ Backend API returned status {resp.status_code} (Server is up, but URL might have changed).")
    except requests.exceptions.ConnectionError:
        print("⚠️ Backend server (manage.py runserver) is NOT running or unreachable at localhost:8000.")
    except Exception as e:
        print(f"❌ API Health check error: {e}")

if __name__ == "__main__":
    test_infrastructure()

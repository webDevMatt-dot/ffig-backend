import os
import django
import requests
import json
from datetime import datetime

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from django.test.client import Client
from members.models import Story
from django.core.files.uploadedfile import SimpleUploadedFile

def run_test():
    # 1. Create a test user
    username = f"testuser_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    password = "password123"
    email = f"{username}@example.com"
    user = User.objects.create_user(username=username, email=email, password=password)
    print(f"Created user: {username}")

    # 2. Login to get token (using Client for simplicity, simulating API)
    client = Client()
    # Force login for client
    client.force_login(user)

    # 3. Post a Story
    media_content = b"fake image content"
    media = SimpleUploadedFile("story.jpg", media_content, content_type="image/jpeg")
    
    response = client.post('/api/members/stories/', {'media': media})
    if response.status_code != 201:
        print(f"FAILED to post story: {response.status_code} - {response.content}")
        return
    
    print("Successfully posted story.")
    story_id = response.json()['id']

    # 4. Fetch Stories
    response = client.get('/api/members/stories/')
    if response.status_code != 200:
        print(f"FAILED to fetch stories: {response.status_code} - {response.content}")
        return

    stories = response.json()
    print(f"Fetched {len(stories)} stories.")
    
    found = False
    for s in stories:
        if s['id'] == story_id:
            found = True
            print(f"Found our story: {s}")
            break
            
    if not found:
        print("ERROR: Posted story not found in list!")
    else:
        print("SUCCESS: Story posted and retrieved correctly.")

    # Cleanup
    Story.objects.filter(id=story_id).delete()
    user.delete()

if __name__ == "__main__":
    run_test()

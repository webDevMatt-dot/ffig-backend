from rest_framework.test import APIClient
from django.contrib.auth.models import User
from members.models import MarketingRequest

def verify():
    print("Verifying VVIP Feed Endpoint...")
    user = User.objects.get(username='admin')
    client = APIClient()
    client.force_authenticate(user=user)
    
    response = client.get('/api/members/marketing/feed/')
    
    if response.status_code == 200:
        data = response.json()
        print(f"Success! Status: 200")
        print(f"Count: {len(data)}")
        if len(data) > 0:
            print(f"First Item Type: {data[0].get('type')}")
            print(f"First Item Title: {data[0].get('title')}")
            # Verify Social fields
            print(f"Likes Count: {data[0].get('likes_count')}")
            print(f"Comments Count: {data[0].get('comments_count')}")
            print(f"Is Liked: {data[0].get('is_liked')}")
    else:
        print(f"Failed! Status: {response.status_code}")
        print(response.content)

verify()

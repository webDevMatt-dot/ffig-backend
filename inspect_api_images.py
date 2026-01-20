import requests
import os
import json

# Configuration
BASE_URL = "https://ffig-backend-ti5w.onrender.com/api"
USERNAME = os.environ.get("FFIG_ADMIN_USERNAME", "admin") # Fallback to admin if not set, or might need user creds
PASSWORD = os.environ.get("FFIG_ADMIN_PASSWORD", "password")

def inspect_images():
    print(f"🔍 Inspecting API: {BASE_URL}")
    
    # 1. Login
    print("🔑 Logging in...")
    try:
        auth_resp = requests.post(f"{BASE_URL}/auth/login/", json={
            "username": USERNAME,
            "password": PASSWORD
        })
        if auth_resp.status_code != 200:
            print(f"❌ Login Failed: {auth_resp.status_code} - {auth_resp.text}")
            return
        
        tokens = auth_resp.json()
        access_token = tokens['access_token']
        headers = {'Authorization': f'Bearer {access_token}'}
        print("✅ Login Success")
    except Exception as e:
        print(f"❌ Connection Error: {e}")
        return

    # 2. Inspect Dashboard (Founder Spotlight)
    print("\n🏠 Inspecting Dashboard (api/home/)...")
    try:
        home_resp = requests.get(f"{BASE_URL}/home/", headers=headers)
        if home_resp.status_code == 200:
            data = home_resp.json()
            # Expecting list of sets. 
            # [0] -> Hero Items
            # [1] -> Founder Profiles
            
            hero_items = data[0] if len(data) > 0 else []
            founders = data[1] if len(data) > 1 else []
            
            print(f"   Found {len(hero_items)} Hero Items")
            for item in hero_items:
                print(f"   - Hero '{item.get('title')}': image='{item.get('image')}'")
                
            print(f"   Found {len(founders)} Founder Profiles")
            for founder in founders:
                print(f"   - Founder '{founder.get('name')}': photo='{founder.get('photo')}'")
        else:
            print(f"❌ Failed to fetch home: {home_resp.status_code}")
    except Exception as e:
        print(f"❌ Error fetching home: {e}")

    # 3. Inspect Member List
    print("\n👥 Inspecting Members (api/members/?limit=5)...")
    try:
        members_resp = requests.get(f"{BASE_URL}/members/?limit=5", headers=headers)
        if members_resp.status_code == 200:
            members = members_resp.json()
            if isinstance(members, dict) and 'results' in members:
                members = members['results']
            
            print(f"   Fetched {len(members)} Members")
            for m in members:
                print(f"   - Member '{m.get('username')}': photo='{m.get('photo')}', photo_url='{m.get('photo_url')}'")
        else:
            print(f"❌ Failed to fetch members: {members_resp.status_code}")
    except Exception as e:
        print(f"❌ Error fetching members: {e}")

if __name__ == "__main__":
    inspect_images()

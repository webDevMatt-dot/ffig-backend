import requests
import random
import string

BASE_URL = "https://ffig-backend-ti5w.onrender.com/api"

def random_string(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def verify_backend():
    print(f"🔍 Connecting to {BASE_URL}...")
    
    # 1. Register Temp User
    username = f"test_debug_{random_string(4)}"
    password = "Password123!"
    email = f"{username}@example.com"
    
    print(f"👤 Registering temp user: {username}...")
    try:
        reg_resp = requests.post(f"{BASE_URL}/auth/register/", json={
            "username": username,
            "password": password,
            "password2": password,
            "email": email,
            "first_name": "Test",
            "last_name": "User"
        })
        
        # 201 Created or maybe 200
        if reg_resp.status_code not in [200, 201]:
            print(f"⚠️ Registration might have failed: {reg_resp.status_code} {reg_resp.text}")
    except Exception as e:
        print(f"❌ Connection Error: {e}")
        return

    # 2. Login
    print("🔑 Logging in...")
    try:
        auth_resp = requests.post(f"{BASE_URL}/auth/login/", json={
            "username": username,
            "password": password
        })
        
        if auth_resp.status_code != 200:
            print(f"❌ Login Failed: {auth_resp.status_code} - {auth_resp.text}")
            return
            
        token = auth_resp.json()['access'] # Assuming 'access' from TokenObtainPair/Custom, or check custom view
        headers = {'Authorization': f'Bearer {token}'}
        print("✅ Login Success")
        
    except Exception as e:
        print(f"❌ Login Error: {e}")
        return

    # 3. Check Founder Feed
    print("🏠 Checking Founder Feed (/home/founder/)...")
    try:
        home_resp = requests.get(f"{BASE_URL}/home/founder/", headers=headers)
        print(f"   Status: {home_resp.status_code}")
        
        if home_resp.status_code == 200:
            founders = home_resp.json()
            # If paginated
            if isinstance(founders, dict) and 'results' in founders:
                founders = founders['results']
                
            print(f"   Found {len(founders)} Founders")
            
            for f in founders:
                photo = f.get('photo')
                print(f"   - Name: {f.get('name')}")
                print(f"   - Photo (Raw): {photo}")
                
                if photo:
                    if "s3.amazonaws" in photo or "onrender.com" in photo: # Render can serve media too if configured
                        print("     ✅ URL looks valid (S3 or Absolute)")
                    else:
                        print("     ⚠️  Using Local/Relative URL (Likely S3 unconfigured or old absolute path missing)")
        else:
             print(f"❌ Failed to fetch founders: {home_resp.text}")
             
    except Exception as e:
        print(f"❌ Founder Feed Error: {e}")

if __name__ == "__main__":
    verify_backend()

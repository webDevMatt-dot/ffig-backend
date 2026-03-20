import requests
import random
import string
import time

BASE_URL = "http://127.0.0.1:8008/api"

def random_string(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def test_iap_verification():
    print(f"🔍 Connecting to {BASE_URL}...")
    
    # 1. Register Temp User
    username = f"test_iap_{random_string(6)}"
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
            "last_name": "IAPUser"
        })
        print(f"Registration Status: {reg_resp.status_code}")
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
            
        token = auth_resp.json().get('access')
        if not token:
            print(f"❌ Could not find access token in response: {auth_resp.json()}")
            return
            
        headers = {'Authorization': f'Bearer {token}'}
        print("✅ Login Success")
        
    except Exception as e:
        print(f"❌ Login Error: {e}")
        return

    # 3. Test IAP Verification Endpoint (Android mock)
    print("💳 Testing IAP Subscription Verification...")
    try:
        # Based on views.py, android platform only requires receipt_data string
        payload = {
            "platform": "android",
            "receipt_data": "mock_android_receipt_data_12345",
            "product_id": "FFIG_PREMIUM"
        }
        
        iap_resp = requests.post(f"{BASE_URL}/payments/verify-subscription/", json=payload, headers=headers)
        print(f"   Status: {iap_resp.status_code}")
        print(f"   Response: {iap_resp.text}")
        
        if iap_resp.status_code == 200:
            print("✅ IAP Verification Endpoint functioning correctly for mock Android receipt.")
        else:
            print("❌ Android IAP Verification Failed")
            
        # 4. Test iOS (should fail since receipt is fake)
        print("💳 Testing iOS IAP Subscription Verification (Fake Receipt)...")
        ios_payload = {
            "platform": "ios",
            "receipt_data": "fake_ios_receipt",
            "product_id": "FFIG_PREMIUM"
        }
        ios_resp = requests.post(f"{BASE_URL}/payments/verify-subscription/", json=ios_payload, headers=headers)
        print(f"   Status: {ios_resp.status_code}")
        print(f"   Response: {ios_resp.text}")
        if ios_resp.status_code == 400 and 'Invalid Receipt' in ios_resp.text:
            print("✅ iOS IAP Verification correctly rejected fake receipt.")
        else:
            print("❌ iOS IAP Verification did not handle fake receipt as expected.")
            
    except Exception as e:
        print(f"❌ IAP Verification Error: {e}")

if __name__ == "__main__":
    test_iap_verification()

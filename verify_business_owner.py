import requests
import os

def test_business_api():
    # Use the same domain as in serializers.py fallback
    domain = os.environ.get('SITE_URL', 'http://localhost:8000')
    url = f"{domain}/api/home/business/"
    
    print(f"Testing Business API at: {url}")
    
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                item = data[0]
                print("✅ API returned data")
                print(f"Business: {item.get('name')}")
                print(f"Owner ID: {item.get('owner_id')}")
                print(f"Owner Name: {item.get('owner_name')}")
                print(f"Owner Photo: {item.get('owner_photo')}")
                
                # Check for new fields
                if 'owner_id' in item and 'owner_name' in item:
                    print("✅ New owner fields are present in API response")
                else:
                    print("❌ New owner fields are MISSING in API response")
            else:
                print("ℹ️ API returned 200 but no business data found (check database)")
        else:
            print(f"❌ API failed with status code: {response.status_code}")
    except Exception as e:
        print(f"❌ Error connecting to API: {e}")

if __name__ == "__main__":
    test_business_api()

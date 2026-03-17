import requests

def test_version_api():
    url = "http://127.0.0.1:8000/api/home/version/"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            ios_versions = [v for v in data if v['platform'] == 'IOS']
            if ios_versions:
                # AppVersionViewSet returns the latest first
                ios_version = ios_versions[0]
                print(f"IOS Update URL: {ios_version['update_url']}")
                expected = "https://apps.apple.com/za/app/female-founders-initiative-glo/id6759861790"
                if ios_version['update_url'] == expected:
                    print("SUCCESS: iOS Update URL is correct.")
                else:
                    print(f"FAILURE: Expected {expected}, got {ios_version['update_url']}")
            else:
                print("FAILURE: No IOS platform found in response.")
        else:
            print(f"FAILURE: API returned status code {response.status_code}")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_version_api()

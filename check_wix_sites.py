import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

with open('.env', 'r') as f:
    env_content = f.read()

lines = env_content.split('\n')
wix_api_key = None
wix_account_id = None
for line in lines:
    if line.startswith("WIX_API_KEY='IST"):
        wix_api_key = line.split("='")[1].rstrip("'")
    elif line.startswith("WIX_API_KEY='14e9"):
        wix_account_id = line.split("='")[1].rstrip("'")

def check_sites():
    print("Fetching Wix Sites for this account...")
    
    # 1. Try Site-Management API to list sites
    url = "https://www.wixapis.com/site-management/v1/sites"
    headers = {
        "Authorization": wix_api_key,
    }
    
    if wix_account_id:
       headers["wix-account-id"] = wix_account_id
       
    print(f"Headers: {headers}")

    response = requests.get(url, headers=headers)
    print(f"Status: {response.status_code}")
    print(response.text)

if __name__ == "__main__":
    check_sites()

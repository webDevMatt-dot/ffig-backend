import os
import requests
import json
from dotenv import load_dotenv

# Load all the environment variables from the .env file
load_dotenv()

# We need the long JWT token one for the API key, not the short UUID
with open('.env', 'r') as f:
    env_content = f.read()

lines = env_content.split('\n')
wix_api_key = None
wix_site_id = None
for line in lines:
    if line.startswith("WIX_API_KEY='IST"):
        wix_api_key = line.split("='")[1].rstrip("'")
    elif line.startswith("WIX_SITE_ID="):
        wix_site_id = line.split("='")[1].split("'")[0]

if not wix_api_key:
    print("Could not find the long WIX_API_KEY starting with 'IST'")
    exit(1)

def get_wix_contacts():
    print("Connecting to Wix Contacts API...")
    # Trying the Wix Contacts API again to see if "All permissions" fixed it
    url = "https://www.wixapis.com/contacts/v4/contacts/query"
    
    headers = {
        "Authorization": wix_api_key,
        "Content-Type": "application/json"
    }
        
    payload = {
        "query": {
            "paging": {
                "limit": 100
            }
        }
    }

    response = requests.post(url, headers=headers, json=payload)
    
    if response.status_code != 200:
        print(f"Error fetching contacts: {response.status_code}")
        print(response.text)
        return

    data = response.json()
    contacts = data.get("contacts", [])
    
    print(f"\nSuccessfully fetched {len(contacts)} contacts from Wix.")
    
    premium_users = []
    standard_users = []
    
    for contact in contacts:
        info = contact.get("info", {})
        emails = info.get("emails", [])
        email = emails[0].get("email") if emails else "No Email"
        
        name = info.get("name", {}).get("first", "") + " " + info.get("name", {}).get("last", "")
        name = name.strip() or "Unnamed"
        
        # Check Labels
        label_keys = contact.get("info", {}).get("labelKeys", [])
        
        # Labels might be returned as UUIDs or strings. Let's print out what we get
        labels_str = " | ".join(label_keys).upper()
        
        if "PREMIUM" in labels_str:    
            premium_users.append((name, email))
        elif "STANDARD" in labels_str:
            standard_users.append((name, email))
            
    print("\n=== PREMIUM USERS IN WIX ===")
    if not premium_users:
         print("No Premium users found.")
    for u in premium_users:
        print(f"- {u[0]} (Email: {u[1]})")
        
    print("\n=== STANDARD USERS IN WIX ===")
    if not standard_users:
         print("No Standard users found.")
    for u in standard_users:
        print(f"- {u[0]} (Email: {u[1]})")

if __name__ == "__main__":
    get_wix_contacts()

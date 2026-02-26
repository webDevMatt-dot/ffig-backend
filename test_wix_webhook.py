import requests
import json

WEBHOOK_URL = "https://ffig-backend-ti5w.onrender.com/api/webhooks/wix/"
SECRET = "jbc3e78duh32g376e783bxd632tv32876e32b3782"

def test_webhook():
    print("Testing Wix Webhook Endpoint...\n")

    headers = {
        "Content-Type": "application/json",
        "X-Wix-Secret": SECRET
    }

    # Test Payload 1: Missing Secret (Should fail 403)
    print("Test 1: Missing Secret")
    res1 = requests.post(WEBHOOK_URL, json={"email": "test@example.com", "labels": ["PREMIUM"]})
    print(f"Status: {res1.status_code}, Response: {res1.text}\n")

    # Test Payload 2: Valid format, fake user
    print("Test 2: Valid payload, Fake user")
    payload2 = {
        "data": {
            "contact": {
                "emails": [{"email": "fakeuser123_not_in_db@example.com"}],
                "labels": ["PREMIUM"]
            }
        }
    }
    res2 = requests.post(WEBHOOK_URL, headers=headers, json=payload2)
    print(f"Status: {res2.status_code}, Response: {res2.text}\n")
    
    # Test Payload 3: Direct fields
    print("Test 3: Direct fields")
    payload3 = {
        "emailAddress": "another_fake@example.com",
        "labels": ["STANDARD"]
    }
    res3 = requests.post(WEBHOOK_URL, headers=headers, json=payload3)
    print(f"Status: {res3.status_code}, Response: {res3.text}\n")

if __name__ == "__main__":
    test_webhook()

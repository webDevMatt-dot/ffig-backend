import requests
import json

base_url = "https://ffig-backend-ti5w.onrender.com/"
login_url = f"{base_url}api/auth/login/"
update_url = f"{base_url}api/admin/users/34/"

# 1. Login to get token
resp = requests.post(login_url, json={"username": "apple", "password": "wrongpassword"})
print("Login status:", resp.status_code)
print("Login body:", resp.text)

# We can't actually do the update if login fails, but let's test a raw PATCH
headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer fake_token_just_to_see_if_we_get_401"
}

payload = {
    "username": "apple",
    "email": "apple@test.com",
    "first_name": "Apple",
    "last_name": "User",
    "is_staff": False,
    "profile": {"tier": "STANDARD"}
}

patch_resp = requests.patch(update_url, headers=headers, json=payload)
print("PATCH status:", patch_resp.status_code)
print("PATCH body:", patch_resp.text)

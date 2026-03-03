import os
import smtplib

SMTP_USER = 'AKIAUTMXCLQN3KDXEPVP'
SMTP_PASS = 'BPcIhHUdkXCW8wQDHaTWFKdNKlNUFhI8gifExZIP3rrX'

REGIONS = [
    'eu-north-1',   # Stockholm
    'eu-west-1',    # Ireland
    'eu-central-1', # Frankfurt
    'eu-west-2',    # London
    'eu-west-3',    # Paris
    'eu-south-1',   # Milan
    'us-east-1',    # N. Virginia
]

for region in REGIONS:
    host = f'email-smtp.{region}.amazonaws.com'
    print(f"\\n--- Testing {region} ({host}) ---")
    try:
        server = smtplib.SMTP(host, 587, timeout=5)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASS)
        print(f"✅ SUCCESS! Credentials are valid in region: {region}")
        server.quit()
        break
    except smtplib.SMTPAuthenticationError:
        print(f"❌ FAILED: Invalid credentials for region {region}")
    except Exception as e:
        print(f"⚠️ ERROR: {e}")

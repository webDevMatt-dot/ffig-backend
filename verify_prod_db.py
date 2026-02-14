import psycopg2
import sys

def check_prod_db():
    print("🚀 FFIG Production DB Verification Script")
    print("---------------------------------------")
    print("Please paste your External Database URL below.")
    print("(It starts with postgres:// and contains 'render.com')")
    
    url = input("Enter URL: ").strip()
    
    if not url:
        print("❌ No URL provided. Exiting.")
        return

    try:
        print("\n🔌 Connecting to database...")
        conn = psycopg2.connect(url)
        cur = conn.cursor()
        
        # 1. Check for Users with FCM Tokens
        print("\n🔍 Checking for FCM Tokens...")
        cur.execute("SELECT COUNT(*) FROM members_profile WHERE fcm_token IS NOT NULL AND fcm_token != '';")
        count = cur.fetchone()[0]
        
        if count > 0:
            print(f"✅ SUCCESS: Found {count} users with FCM tokens!")
            
            # Show details of first few
            cur.execute("SELECT user_id, fcm_token FROM members_profile WHERE fcm_token IS NOT NULL AND fcm_token != '' LIMIT 5;")
            rows = cur.fetchall()
            for row in rows:
                print(f"   - User ID: {row[0]}, Token: {row[1][:10]}... (truncated)")
        else:
            print("❌ FAILURE: No users have FCM tokens stored.")
            print("   This means the mobile app has not successfully sent the token to the backend yet.")

        # 2. Check for Notifications
        print("\n🔍 Checking for Notifications...")
        cur.execute("SELECT COUNT(*) FROM members_notification;")
        notif_count = cur.fetchone()[0]
        print(f"ℹ️  Total Notifications in DB: {notif_count}")
        
        if notif_count > 0:
            cur.execute("SELECT id, title, is_read, created_at, recipient_id FROM members_notification ORDER BY created_at DESC LIMIT 5;")
            rows = cur.fetchall()
            print("   Latest 5 Notifications:")
            for row in rows:
                print(f"   - ID: {row[0]} | Title: {row[1]} | Read: {row[2]} | Recipient ID: {row[4]} | Time: {row[3]}")

        # 3. Check for Chat Messages
        print("\n🔍 Checking for Chat Messages...")
        cur.execute("SELECT COUNT(*) FROM chat_message;")
        msg_count = cur.fetchone()[0]
        print(f"ℹ️  Total Chat Messages in DB: {msg_count}")
        
        if msg_count > 0:
            cur.execute("SELECT id, text, sender_id, created_at FROM chat_message ORDER BY created_at DESC LIMIT 5;")
            rows = cur.fetchall()
            print("   Latest 5 Messages:")
            for row in rows:
                print(f"   - ID: {row[0]} | Sender: {row[2]} | Content: {row[1][:20]}... | Time: {row[3]}")

        cur.close()
        conn.close()
        print("\n---------------------------------------")
        print("Done.")

    except Exception as e:
        print(f"\n❌ ERROR Connecting to DB: {e}")
        print("Make sure you are using the EXTERNAL Database URL (ends in .render.com)")

if __name__ == "__main__":
    check_prod_db()

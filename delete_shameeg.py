
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def delete_user():
    try:
        user = User.objects.get(username__iexact='Shameeg')
        print(f"Found user: {user.username} (ID: {user.id}, Email: {user.email})")
        user.delete()
        print("User deleted successfully.")
    except User.DoesNotExist:
        print("User 'Shameeg' not found by username. Trying email...")
        try:
            user = User.objects.get(email__iexact='shameegd@gmail.com')
            print(f"Found user by email: {user.username} (ID: {user.id}, Email: {user.email})")
            user.delete()
            print("User deleted successfully.")
        except User.DoesNotExist:
            print("User not found by username or email.")
        except Exception as e:
            print(f"Error deleting by email: {e}")
    except Exception as e:
        print(f"Error deleting by username: {e}")

if __name__ == "__main__":
    delete_user()

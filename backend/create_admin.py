
import os
import sys

from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables from backend/.env
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SECRET_KEY")

# Check required environment variables
if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("❌ Missing Supabase URL or secret key in .env")
    sys.exit(1)

# Initialize Supabase client
supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY
)


def create_admin(email: str, password: str, name: str = "Admin User"):

    user_id = None

    # STEP 1: Try creating the authentication user
    try:
        response = supabase.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {
                "name": name
            }
        })

        user_id = response.user.id
        print(f"✅ Auth user created successfully: {user_id}")

    except Exception as e:

        if "already been registered" in str(e).lower():

            print("⚠️ User already exists – updating password.")

            try:
                # Retrieve existing users
                users = supabase.auth.admin.list_users()

                # Find matching email
                existing_user = next(
                    (
                        user for user in users
                        if user.email and user.email.lower() == email.lower()
                    ),
                    None
                )

                if not existing_user:
                    print("❌ Existing user could not be found.")
                    return

                user_id = existing_user.id

                # Update existing user's password
                supabase.auth.admin.update_user_by_id(
                    user_id,
                    {
                        "password": password
                    }
                )

                print("✅ Existing admin password updated!")

            except Exception as update_error:
                print("❌ Error updating existing user:", update_error)
                return

        else:
            print("❌ Auth user creation error:", e)
            return

    # STEP 2: Create or update the admin profile
    try:

        profile_data = {
            "id": user_id,
            "email": email,
            "name": name,
            "staff": True
        }

        # Upsert prevents duplicate profile records
        supabase.table("profiles").upsert(
            profile_data,
            on_conflict="id"
        ).execute()

        print("✅ Admin profile created/updated successfully!")

    except Exception as db_error:
        print("❌ Profile insertion/update error:", db_error)
        return

    print("\n🎉 Admin setup completed successfully!")


if __name__ == "__main__":

    admin_email = os.getenv("ADMIN_EMAIL")
    admin_password = os.getenv("ADMIN_PASSWORD")
    if not admin_email or not admin_password:
        print("Set ADMIN_EMAIL and ADMIN_PASSWORD before creating an admin.")
        sys.exit(1)

    admin_name = os.getenv("ADMIN_NAME", "Admin")
    create_admin(admin_email, admin_password, admin_name)

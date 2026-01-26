import asyncio
import sys
import os

# Ensure the current directory is in sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

print(f"Current dir: {current_dir}")

try:
    from app.db.core import AsyncSessionLocal
    from app.api.notifications.service import create_notification
    from app.api.notifications.models import NotificationType
except ImportError as e:
    print(f"Import Error: {e}")
    # Try appending parent dir if app is not found
    parent_dir = os.path.dirname(current_dir)
    sys.path.append(parent_dir)
    try:
        from app.db.core import AsyncSessionLocal
        from app.api.notifications.service import create_notification
        from app.api.notifications.models import NotificationType
    except ImportError as e2:
        print(f"Import Error 2: {e2}")
        sys.exit(1)

async def main():
    async with AsyncSessionLocal() as session:
        # User ID from logs
        user_id = 640
        print(f"Creating test notification for user {user_id}...")
        
        try:
            notification = await create_notification(
                session=session,
                user_id=user_id,
                title="Test Notification",
                description="This is a test notification created manually to verify the list.",
                type=NotificationType.club_announcement.value,
                data={"test": True}
            )
            print(f"Successfully created notification: {notification.id}")
        except Exception as e:
            print(f"Error creating notification: {e}")

if __name__ == "__main__":
    asyncio.run(main())

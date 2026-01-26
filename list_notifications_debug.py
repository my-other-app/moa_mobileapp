import asyncio
import sys
import os
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# Ensure the current directory is in sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

try:
    from app.db.core import AsyncSessionLocal
    from app.api.notifications.models import Notifications
except ImportError as e:
    # Try appending parent dir if app is not found
    parent_dir = os.path.dirname(current_dir)
    sys.path.append(parent_dir)
    from app.db.core import AsyncSessionLocal
    from app.api.notifications.models import Notifications

async def main():
    async with AsyncSessionLocal() as session:
        user_id = 640
        print(f"Listing notifications for user {user_id}...")
        
        query = (
            select(Notifications)
            .where(Notifications.user_id == user_id)
            .options(
                selectinload(Notifications.from_club),
                selectinload(Notifications.from_user),
                selectinload(Notifications.event),
            )
            .order_by(Notifications.created_at.desc())
        )
        
        result = await session.execute(query)
        notifications = result.scalars().all()
        
        print(f"Found {len(notifications)} notifications.")
        
        for n in notifications:
            print(f"ID: {n.id}, Title: {n.title}, Status: {n.status}, Created: {n.created_at}")
            print(f"  From Club: {n.from_club.name if n.from_club else 'None'}")
            print(f"  From User: {n.from_user.full_name if n.from_user else 'None'}")
            print(f"  Event: {n.event.name if n.event else 'None'}")
            print("-" * 20)

if __name__ == "__main__":
    asyncio.run(main())

from pathlib import Path
import sys

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.core.database import close_mongo_connection, connect_to_mongo
from app.db.seed import seed_database


async def main() -> None:
    await connect_to_mongo()
    summary = await seed_database()
    print(summary)
    await close_mongo_connection()


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())

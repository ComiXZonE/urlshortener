import os
import sqlite3
from contextlib import closing

class ShortenDB:
    def __init__(self):
        self.path = os.getenv("DB_PATH", "shortener.db")
        with closing(self._connect()) as conn, conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS urls "
                "(code TEXT PRIMARY KEY, url TEXT NOT NULL)"
            )

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.path, timeout=5)

    def insert_into_urls(self, code: str, url: str) -> bool:
        """Return True if inserted, False if the code already exists."""
        try:
            with closing(self._connect()) as conn, conn:
                conn.execute(
                    "INSERT INTO urls (code, url) VALUES (?, ?)", (code, url)
                )
            return True
        except sqlite3.IntegrityError:
            return False

    def get_url(self, code: str) -> str | None:
        with closing(self._connect()) as conn:
            row = conn.execute(
                "SELECT url FROM urls WHERE code = ?", (code,)
            ).fetchone()
        return row[0] if row else None
from db import ShortenDB
from shorten import make_code
from fastapi import FastAPI

db = ShortenDB()
app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/shorten")
def shorten(url: str):
    for attempt in range(10):
        code = make_code(url, attempt=attempt)
        if db.insert_into_urls(code, url):
            return code                  # new URL stored
        if db.get_url(code) == url:
            return code                  # same URL shortened before: reuse it
        # otherwise: different URL, real collision, retry with next attempt
    raise RuntimeError("could not allocate a code")

@app.get("/{code}")
def get(code: str):
    return db.get_url(code)
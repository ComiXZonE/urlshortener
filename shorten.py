import hashlib

ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def base62_encode(n: int) -> str:
    if n == 0:
        return ALPHABET[0]
    chars = []
    while n:
        n, rem = divmod(n, 62)
        chars.append(ALPHABET[rem])
    return "".join(reversed(chars))

def make_code(url: str, length: int = 7, attempt: int = 0) -> str:
    digest = hashlib.sha256(f"{url}:{attempt}".encode()).digest()
    n = int.from_bytes(digest[:8], "big") % 62**length
    return base62_encode(n).rjust(length, ALPHABET[0])
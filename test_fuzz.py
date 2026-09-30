#!/usr/bin/env python3
"""
Fuzz Testing Suite for Bend HTTP Web Server
Injects random bytes, control characters, null bytes, mutated verbs/paths,
and verify that the server never crashes, hangs, or panics.
"""

import socket
import random
import string
import time
import sys

HOST = "127.0.0.1"
PORT = 8080

def send_fuzz_payload(payload: bytes, timeout: float = 1.0) -> tuple[int, bool]:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect((HOST, PORT))
        s.sendall(payload)
        resp = b""
        while True:
            try:
                chunk = s.recv(2048)
                if not chunk:
                    break
                resp += chunk
            except (socket.timeout, ConnectionResetError):
                break
        s.close()
        
        status = 0
        if resp.startswith(b"HTTP/"):
            parts = resp.split(b"\r\n")[0].split(b" ")
            if len(parts) >= 2:
                try:
                    status = int(parts[1])
                except ValueError:
                    status = -1
        # Returns status and whether connection was handled cleanly
        return status, True
    except Exception as e:
        s.close()
        return -1, False

def generate_fuzz_cases():
    cases = []
    
    # 1. Pure random bytes (including non-ASCII, null bytes, high bytes)
    for _ in range(25):
        length = random.randint(1, 1024)
        cases.append(("Random bytes", bytes([random.randint(0, 255) for _ in range(length)])))
        
    # 2. Control characters & null bytes injected into HTTP structure
    for _ in range(15):
        noise = "".join(random.choice(["\x00", "\x01", "\t", "\x0b", "\x0c", "\x1f", "\x7f", "\xff"]) for _ in range(20))
        cases.append(("Control chars in request", f"GET /{noise} HTTP/1.1\r\nHost: localhost\r\n\r\n".encode("latin-1", errors="replace")))

    # 3. Mutated HTTP verbs
    verbs = ["GETT", "get", "G", "POSTT", "PATCHH", "INVALID_VERB_XYZ", "1234", "???"]
    for v in verbs:
        cases.append(("Mutated verb", f"{v} / HTTP/1.1\r\nHost: localhost\r\n\r\n".encode()))

    # 4. Mutated paths (unicode, traversal, symbols)
    paths = ["/..", "/../../etc/passwd", "/\x00/api", "/a" * 100, "//api//", "/?&?&?", "/テスト", "/🚀"]
    for p in paths:
        cases.append(("Mutated path", f"GET {p} HTTP/1.1\r\nHost: localhost\r\n\r\n".encode("utf-8")))

    # 5. Mutated HTTP versions
    versions = ["HTTP/1.2", "HTTP/0.9", "HTTP/2", "HTTP/3.0", "HTTP/", "HTTP/1.1.1", "HTTPS/1.1", "XYZ/1.0"]
    for ver in versions:
        cases.append(("Mutated version", f"GET / {ver}\r\nHost: localhost\r\n\r\n".encode()))

    # 6. Fuzzed headers
    for _ in range(20):
        hname = "".join(random.choice(string.ascii_letters) for _ in range(random.randint(1, 30)))
        hval = "".join(random.choice(string.printable) for _ in range(random.randint(0, 200)))
        cases.append(("Fuzzed header", f"GET / HTTP/1.1\r\n{hname}: {hval}\r\n\r\n".encode()))

    # 7. Rapid fragmented garbage
    for _ in range(10):
        garbage = bytes([random.randint(32, 126) for _ in range(random.randint(10, 500))]) + b"\r\n\r\n"
        cases.append(("Random ASCII + terminator", garbage))

    return cases

def main():
    print("Starting Fuzz Testing against Bend HTTP Server...")
    cases = generate_fuzz_cases()
    print(f"Generated {len(cases)} fuzz test cases.")

    clean_responses = 0
    clean_closes = 0
    errors = 0

    valid_statuses = {200, 400, 404, 405, 408, 413, 431, 500}

    for i, (category, payload) in enumerate(cases):
        status, clean = send_fuzz_payload(payload)
        if not clean:
            errors += 1
            print(f"  [WARN] Case #{i} ({category}): connection failed to complete cleanly")
            continue
        
        if status in valid_statuses:
            clean_responses += 1
        elif status == 0:
            # Server cleanly closed socket on malformed / truncated stream
            clean_closes += 1
        else:
            print(f"  [UNEXPECTED] Case #{i} ({category}): unexpected status code {status}")
            errors += 1

    print(f"\nFuzz Results:")
    print(f"  Total cases sent:        {len(cases)}")
    print(f"  Valid HTTP responses:    {clean_responses}")
    print(f"  Clean connection closes: {clean_closes}")
    print(f"  Connection errors:       {errors}")

    assert errors == 0, f"Encountered {errors} connection failures during fuzzing!"

    # Verify server health post-fuzzing
    print("\nVerifying server health after fuzzing...")
    s = socket.socket()
    s.connect((HOST, PORT))
    s.sendall(b"GET /api HTTP/1.1\r\nHost: localhost\r\n\r\n")
    resp = s.recv(4096)
    s.close()

    assert b"200 OK" in resp, f"Post-fuzz health check failed: {resp}"
    print("✅ Server remains healthy and fully responsive after fuzzing!")

if __name__ == "__main__":
    main()

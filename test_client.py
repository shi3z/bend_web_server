#!/usr/bin/env python3
import urllib.request
import urllib.error
import json
import sys

BASE_URL = "http://127.0.0.1:8080"

def test_endpoint(path, expected_status=200):
    url = f"{BASE_URL}{path}"
    print(f"\n[Testing] GET {path}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BendTest/1.0"})
        with urllib.request.urlopen(req, timeout=5) as response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            body = response.read().decode("utf-8")
            print(f"  Status: {status} (Expected: {expected_status})")
            print(f"  Content-Type: {content_type}")
            print(f"  Body preview: {body[:100]}...")
            assert status == expected_status, f"Expected {expected_status}, got {status}"
            return body
    except urllib.error.HTTPError as e:
        print(f"  Status: {e.code} (Expected: {expected_status})")
        print(f"  Body preview: {e.read().decode('utf-8')[:100]}...")
        assert e.code == expected_status, f"Expected {expected_status}, got {e.code}"
        return None

def main():
    print("Testing Bend Web Server endpoints...")
    # 1. Home
    test_endpoint("/", 200)

    # 2. Hello
    test_endpoint("/hello", 200)

    # 3. About
    test_endpoint("/about", 200)

    # 4. API (JSON)
    body = test_endpoint("/api", 200)
    data = json.loads(body)
    print(f"  Parsed JSON successfully: {data}")
    assert data.get("server") == "Bend HTTP Server"

    # 5. 404
    test_endpoint("/nonexistent", 404)

    print("\n✅ All endpoint tests PASSED successfully!")

if __name__ == "__main__":
    main()

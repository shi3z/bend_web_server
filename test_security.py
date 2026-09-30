#!/usr/bin/env python3
"""
Comprehensive Security and Robustness Test Suite for Bend Web Server
Tests RFC compliance, TCP fragmentation, malformed requests, smuggling vectors, and resilience.
"""

import socket
import time
import sys

HOST = "127.0.0.1"
PORT = 8080

def send_raw_request(payload: bytes, read_timeout: float = 3.0, chunk_size: int = 4096) -> tuple[int, bytes]:
    """Sends raw bytes over a TCP socket and returns (status_code, full_response)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(read_timeout)
    try:
        s.connect((HOST, PORT))
        s.sendall(payload)
        resp = b""
        while True:
            try:
                chunk = s.recv(chunk_size)
                if not chunk:
                    break
                resp += chunk
            except (socket.timeout, ConnectionResetError):
                break
        s.close()
        
        # Parse status code
        status = 0
        if resp.startswith(b"HTTP/"):
            parts = resp.split(b"\r\n")[0].split(b" ")
            if len(parts) >= 2:
                try:
                    status = int(parts[1])
                except ValueError:
                    status = -1
        return status, resp
    except Exception as e:
        s.close()
        return -1, str(e).encode()

def test_group(name: str):
    print(f"\n{'='*20} {name} {'='*20}")

def assert_status(expected: int, actual: int, desc: str):
    if actual == expected:
        print(f"  [PASS] {desc} (Got {actual})")
    else:
        print(f"  [FAIL] {desc} (Expected {expected}, Got {actual})")
        assert actual == expected, f"{desc}: expected {expected}, got {actual}"

def main():
    print("Starting Security & Robustness Tests against Bend HTTP Server...")

    # 1. Normal Requests
    test_group("1. Normal Requests (200 OK)")
    for path in ["/", "/hello", "/about", "/api"]:
        st, _ = send_raw_request(f"GET {path} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        assert_status(200, st, f"GET {path}")

    # 2. Strict Routing
    test_group("2. Strict Routing Validation")
    st, _ = send_raw_request(b"GET /apiXYZ HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(404, st, "/apiXYZ must not match /api (404)")

    st, _ = send_raw_request(b"GET /hellofoobar HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(404, st, "/hellofoobar must not match /hello (404)")

    st, _ = send_raw_request(b"GET /about-something HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(404, st, "/about-something must not match /about (404)")

    st, _ = send_raw_request(b"GET /api?query=1&token=xyz HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(200, st, "/api?query=1&token=xyz routes to /api (200)")

    st, _ = send_raw_request(b"GET /hello?name=Antigravity HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(200, st, "/hello?name=Antigravity routes to /hello (200)")

    # 3. TCP Fragmentation (Byte Stream Handling)
    test_group("3. TCP Fragmentation & Streaming Tests")
    
    # 3a. Split request line across two chunks
    s = socket.socket()
    s.connect((HOST, PORT))
    s.sendall(b"GET /ap")
    time.sleep(0.05)
    s.sendall(b"i HTTP/1.1\r\nHost: localhost\r\n\r\n")
    resp = s.recv(4096)
    s.close()
    assert b"200 OK" in resp, f"Split request line failed: {resp}"
    print("  [PASS] Request line split across 2 TCP packets")

    # 3b. Split \r\n\r\n terminator
    s = socket.socket()
    s.connect((HOST, PORT))
    s.sendall(b"GET /hello HTTP/1.1\r\nHost: localhost\r\n")
    time.sleep(0.05)
    s.sendall(b"\r\n")
    resp = s.recv(4096)
    s.close()
    assert b"200 OK" in resp, f"Split terminator failed: {resp}"
    print("  [PASS] Header terminator \\r\\n\\r\\n split across 2 TCP packets")

    # 3c. 1 byte at a time (Trickle send)
    s = socket.socket()
    s.connect((HOST, PORT))
    req = b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
    for b in req:
        s.sendall(bytes([b]))
        time.sleep(0.005)
    resp = s.recv(4096)
    s.close()
    assert b"200 OK" in resp, f"1-byte trickle send failed: {resp}"
    print("  [PASS] 1-byte trickle streaming processed successfully")

    # 4. Malformed Requests (400 Bad Request)
    test_group("4. Malformed Requests")
    st, _ = send_raw_request(b"GET\r\n\r\n")
    assert_status(400, st, "Method only: 'GET\\r\\n\\r\\n'")

    st, _ = send_raw_request(b"GET /\r\n\r\n")
    assert_status(400, st, "Missing HTTP version: 'GET /\\r\\n\\r\\n'")

    st, _ = send_raw_request(b"GET HTTP/1.1\r\n\r\n")
    assert_status(400, st, "Missing path target")

    st, _ = send_raw_request(b"GET / HTTP/2.0\r\n\r\n")
    assert_status(400, st, "Unsupported HTTP/2.0 on HTTP/1.1 socket")

    st, _ = send_raw_request(b"GET relative-path HTTP/1.1\r\n\r\n")
    assert_status(400, st, "Target without leading slash")

    st, _ = send_raw_request(b"GET / HTTP/1.1\r\nBrokenHeaderWithoutColon\r\n\r\n")
    assert_status(400, st, "Malformed header line without colon")

    # LF-only line breaks (permissive robustness)
    st, _ = send_raw_request(b"GET / HTTP/1.1\nHost: localhost\n\n")
    assert_status(200, st, "LF-only line breaks accepted")

    # 5. Method Not Allowed (405)
    test_group("5. HTTP Method Handling")
    for m in ["POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH"]:
        st, _ = send_raw_request(f"{m} / HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        assert_status(405, st, f"{m} method returned 405 Method Not Allowed")

    # 6. HTTP Request Smuggling & Security Limits
    test_group("6. Security & Request Smuggling Protection")
    
    # 6a. Duplicate Content-Length
    st, _ = send_raw_request(b"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10\r\nContent-Length: 20\r\n\r\n")
    assert_status(400, st, "Duplicate Content-Length rejected (400)")

    # 6b. Content-Length + Transfer-Encoding conflict
    st, _ = send_raw_request(b"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nTransfer-Encoding: chunked\r\n\r\n")
    assert_status(400, st, "Content-Length + Transfer-Encoding conflict rejected (400)")

    # 6c. Transfer-Encoding alone rejected (unsupported / smuggling risk)
    st, _ = send_raw_request(b"GET / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n")
    assert_status(400, st, "Transfer-Encoding rejected (400)")

    # 6d. Payload Too Large (413)
    st, _ = send_raw_request(b"GET / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 999999\r\n\r\n")
    assert_status(413, st, "Oversized Content-Length (>64KB) returns 413")

    # 6e. Header Fields Too Large (431)
    huge_header = b"GET / HTTP/1.1\r\nHost: localhost\r\nX-Padding: " + (b"A" * 17000) + b"\r\n\r\n"
    st, _ = send_raw_request(huge_header)
    assert_status(431, st, "Header exceeding 16KB returns 431 Request Header Fields Too Large")

    # 7. Connection Resilience & Error Recovery
    test_group("7. Resilience & Connection Recovery")
    
    # 7a. Immediate client disconnect without sending bytes
    s = socket.socket()
    s.connect((HOST, PORT))
    s.close()
    time.sleep(0.05)
    print("  [PASS] Empty connection closed without crashing server")

    # 7b. Half-sent request followed by immediate disconnect
    s = socket.socket()
    s.connect((HOST, PORT))
    s.sendall(b"GET /incomplete")
    s.close()
    time.sleep(0.05)
    print("  [PASS] Incomplete request aborted without crashing server")

    # 7c. Subsequent normal connection succeeds immediately after failures
    st, _ = send_raw_request(b"GET /api HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_status(200, st, "Server remains fully operational after aborted connections")

    # 7d. Rapid sequential connections
    print("  Testing 30 rapid sequential requests...")
    for i in range(30):
        st, _ = send_raw_request(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
        assert st == 200, f"Rapid connection {i} failed with status {st}"
    print("  [PASS] 30 rapid sequential requests succeeded")

    print("\n" + "="*50)
    print("🎉 ALL SECURITY & ROBUSTNESS TESTS PASSED!")
    print("="*50)

if __name__ == "__main__":
    main()

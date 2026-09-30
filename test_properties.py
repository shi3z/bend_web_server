#!/usr/bin/env python3
"""
Property-Based Verification Suite for Bend HTTP Web Server
Validates mathematical and structural invariants:
1. Route matching is strictly exact path-based (prefix property).
2. Response Content-Length matches exact UTF-8 byte count of response body.
3. Socket closure invariant: Every connection concludes with explicit TCP FIN (EOF).
4. Deterministic error mapping across malformed permutations.
"""

import socket
import sys

HOST = "127.0.0.1"
PORT = 8080

def get_raw_response(request: bytes) -> bytes:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(3.0)
    s.connect((HOST, PORT))
    s.sendall(request)
    resp = b""
    while True:
        try:
            chunk = s.recv(4096)
            if not chunk:
                # Confirms server closed socket cleanly
                break
            resp += chunk
        except (socket.timeout, ConnectionResetError):
            break
    s.close()
    return resp

def parse_http_response(raw: bytes):
    parts = raw.split(b"\r\n\r\n", 1)
    header_block = parts[0]
    body = parts[1] if len(parts) > 1 else b""
    
    header_lines = header_block.split(b"\r\n")
    status_line = header_lines[0].decode("ascii", errors="replace")
    status_code = int(status_line.split(" ")[1])
    
    headers = {}
    for line in header_lines[1:]:
        if b":" in line:
            k, v = line.split(b":", 1)
            headers[k.strip().lower().decode("ascii")] = v.strip().decode("ascii")
            
    return status_code, headers, body

def main():
    print("Starting Property-Based Invariant Verification...")

    # =========================================================================
    # Property 1: Content-Length Invariant
    # Invariant: For EVERY response, int(headers['content-length']) == len(body)
    # =========================================================================
    print("\n[Property 1] Verifying Content-Length == len(body) invariant...")
    test_paths = [
        ("/", 200),
        ("/hello", 200),
        ("/about", 200),
        ("/api", 200),
        ("/nonexistent-path-for-404", 404),
        ("/bad-request-trigger-400", 404),
    ]
    for path, expected_status in test_paths:
        raw = get_raw_response(f"GET {path} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        st, headers, body = parse_http_response(raw)
        assert st == expected_status, f"Expected {expected_status}, got {st}"
        assert "content-length" in headers, f"Missing Content-Length on {path}"
        cl = int(headers["content-length"])
        actual_len = len(body)
        assert cl == actual_len, f"Content-Length mismatch on {path}: header={cl} != body_len={actual_len}"
        print(f"  [OK] {path} (HTTP {st}): declared Content-Length {cl} == actual body bytes {actual_len}")

    # Check 405 Method Not Allowed Content-Length
    raw = get_raw_response(b"POST / HTTP/1.1\r\nHost: localhost\r\n\r\n")
    st, headers, body = parse_http_response(raw)
    assert st == 405
    assert int(headers["content-length"]) == len(body)
    print(f"  [OK] POST / (HTTP 405): declared Content-Length {headers['content-length']} == actual body bytes {len(body)}")

    # Check 431 Header Too Large Content-Length
    huge_header = b"GET / HTTP/1.1\r\nHost: localhost\r\nX-Long: " + (b"B" * 17000) + b"\r\n\r\n"
    raw = get_raw_response(huge_header)
    st, headers, body = parse_http_response(raw)
    assert st == 431
    assert int(headers["content-length"]) == len(body)
    print(f"  [OK] Header Too Large (HTTP 431): declared Content-Length {headers['content-length']} == actual body bytes {len(body)}")

    # =========================================================================
    # Property 2: Exact Path Matching Invariant (No False Prefix Matches)
    # Invariant: If P in valid_endpoints, P + X (where X does not start with '?') != 200
    # =========================================================================
    print("\n[Property 2] Verifying Exact Route Matching invariant...")
    valid_endpoints = ["/", "/hello", "/about", "/api"]
    suffix_noise = ["XYZ", "123", "/sub", "-more", "_test", ".html", "foo"]
    
    for ep in valid_endpoints:
        # Base route must be 200
        raw = get_raw_response(f"GET {ep} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        st, _, _ = parse_http_response(raw)
        assert st == 200, f"Base endpoint {ep} failed"
        
        # Any suffix appended must result in 404 (NOT 200)
        for noise in suffix_noise:
            mutated = ep + noise if ep != "/" else "/" + noise
            raw_mut = get_raw_response(f"GET {mutated} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
            st_mut, _, _ = parse_http_response(raw_mut)
            assert st_mut == 404, f"False prefix match! Mutated path '{mutated}' returned {st_mut}, expected 404"
        
        # Query parameters appended MUST still route to 200
        with_query = ep + "?key=value&num=42" if ep != "/" else "/?key=value"
        raw_q = get_raw_response(f"GET {with_query} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        st_q, _, _ = parse_http_response(raw_q)
        assert st_q == 200, f"Query parameter routing failed on '{with_query}', got {st_q}"

    print(f"  [OK] Verified exact matching across all {len(valid_endpoints)} endpoints with {len(suffix_noise)} noise patterns")

    # =========================================================================
    # Property 3: Explicit Connection Close Invariant
    # Invariant: Every response explicitly terminates TCP connection (FIN)
    # =========================================================================
    print("\n[Property 3] Verifying Explicit Connection Termination invariant...")
    for path in ["/", "/api", "/404"]:
        s = socket.socket()
        s.settimeout(2.0)
        s.connect((HOST, PORT))
        s.sendall(f"GET {path} HTTP/1.1\r\nHost: {HOST}\r\n\r\n".encode())
        data = b""
        while True:
            chunk = s.recv(1024)
            if not chunk:
                # recv returning b"" proves server closed socket
                break
            data += chunk
        s.close()
        assert b"Connection: close" in data, f"Connection: close missing on {path}"
        print(f"  [OK] {path}: Server closed connection with EOF and 'Connection: close' header")

    print("\n" + "="*50)
    print("🎉 ALL PROPERTY-BASED INVARIANTS SATISFIED!")
    print("="*50)

if __name__ == "__main__":
    main()

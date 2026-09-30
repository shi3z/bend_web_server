#!/usr/bin/env python3
"""
Concurrency Benchmark for Bend Web Server
Tests concurrent client connections and measures throughput and limits.
"""

import socket
import threading
import time
import sys

HOST = "127.0.0.1"
PORT = 8080

def client_worker(results, index):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(4.0)
        s.connect((HOST, PORT))
        s.sendall(b"GET /api HTTP/1.1\r\nHost: localhost\r\n\r\n")
        resp = b""
        while True:
            chunk = s.recv(1024)
            if not chunk:
                break
            resp += chunk
        s.close()
        if b"200 OK" in resp:
            results[index] = True
        else:
            results[index] = False
    except Exception:
        results[index] = False

def run_concurrent_test(concurrency: int):
    results = [False] * concurrency
    threads = []
    start_time = time.time()
    
    for i in range(concurrency):
        t = threading.Thread(target=client_worker, args=(results, i))
        threads.append(t)
        t.start()
        
    for t in threads:
        t.join()
        
    duration = time.time() - start_time
    success_count = sum(1 for r in results if r)
    rps = success_count / duration if duration > 0 else 0
    print(f"  Concurrency {concurrency:4d}: {success_count}/{concurrency} succeeded in {duration:.2f}s ({rps:.1f} req/s)")
    return success_count == concurrency

def main():
    print("Testing concurrency scalability of Bend HTTP Server...")
    for c in [10, 50, 100, 200]:
        ok = run_concurrent_test(c)
        if not ok:
            print(f"  Scaling limit reached around {c} concurrent connections.")
            break
        time.sleep(0.2)

if __name__ == "__main__":
    main()

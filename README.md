# Robust Bend HTTP Web Server

A hardened, concurrent HTTP/1.1 web server implemented from scratch in **[Bend](https://bend-lang.com/)** (developed by HigherOrderCO).

Bend is a high-level, massively parallel, pure functional programming language powered by **Interaction Combinators** and the **HVM2** runtime.

This implementation emphasizes real-world TCP streaming robustness, strict HTTP/1.1 parsing, and minimization of `@unsafe` boundaries.

---

## 🌟 Security & Robustness Highlights

1. **TCP Stream Buffering (No Single-Recv Assumption)**:
   - Does not assume an HTTP request fits in a single TCP packet.
   - Buffers incoming chunks via non-blocking `TCP.poll` until the header boundary (`\r\n\r\n` or `\n\n`) is reached.
   - Enforces a **16 KB header size limit** (`MAX_HEADER_BYTES = 16384`) to prevent memory exhaustion; returns `431 Request Header Fields Too Large` on overflow.
   - Handles connection reset, EOF (empty recv), and timeouts cleanly without crashing.

2. **Strict Request Line Parsing**:
   - Rejects naive prefix matching (e.g., `/apiXYZ` will **never** match `/api`).
   - Parses `[Method, Target, Version]` strictly separated by spaces.
   - Separates path from query parameters (e.g., `/api?x=1` routes accurately to `/api`).
   - Supports `GET`; rejects non-GET methods (`POST`, `PUT`, `DELETE`, etc.) with `405 Method Not Allowed`.
   - Rejects malformed request lines with `400 Bad Request`.

3. **HTTP Header Validation & Smuggling Mitigation**:
   - Detects malformed header lines lacking a colon (`:`).
   - Validates `Content-Length` headers:
     - Rejects non-integer values with `400 Bad Request`.
     - Rejects duplicate `Content-Length` headers to eliminate request smuggling risks.
     - Enforces a **64 KB payload size limit** (`MAX_BODY_BYTES = 65536`); returns `413 Payload Too Large` when exceeded.
     - Disallows request bodies on `GET` requests (`400 Bad Request`).
   - Rejects `Transfer-Encoding` and conflicting `Transfer-Encoding` + `Content-Length` combinations with `400 Bad Request` (RFC 9112 §6.1).

4. **Minimized `@unsafe` Boundary**:
   - All HTTP request parsing, header validation, exact routing, and response serialization are **100% pure functions** statically verified by Bend's checker.
   - `@unsafe` is strictly confined to external I/O syscalls (`TCP.poll`, `TCP.accept`, `TCP.send`, `Socket.close`) and non-terminating server event loops.

5. **Strict Socket Lifecycle & Affine Safety**:
   - Every socket handle is tracked as an affine resource.
   - Every execution branch (successful response, parse error, send failure, read timeout, EOF) terminates with an explicit `Socket.close(s)`.
   - Never drops or double-closes sockets.

6. **Resilient Listener Loop**:
   - Connection-level accept errors do not terminate the server loop; recoverable errors are logged, and the listener immediately continues accepting incoming connections.

---

## 📂 Project Structure

- [`server.bend`](server.bend) — HTTP server implementation in Bend.
- [`start.sh`](start.sh) — Startup script.
- [`test_client.py`](test_client.py) — Basic functional test client.
- [`test_security.py`](test_security.py) — Security, RFC compliance, and fragmentation test suite.
- [`test_properties.py`](test_properties.py) — Invariant and property-based test suite.
- [`test_fuzz.py`](test_fuzz.py) — Mutation and random-byte fuzz test suite.
- [`README.md`](README.md) — Technical documentation.

---

## 🚀 Quick Start

### 1. Start the Server

```bash
cd /home/shi3z/bend-web-server
./start.sh
```

Or run directly with the Bend CLI:

```bash
bend server.bend
```

### 2. Verify with Test Suites

```bash
# Basic endpoint test
python3 test_client.py

# Security & fragmentation test
python3 test_security.py

# Property-based invariant test
python3 test_properties.py

# Fuzzing test (randomized bytes, corrupted syntax)
python3 test_fuzz.py
```

---

## 🔬 Boundary of Guarantees: What Is and Isn't Guaranteed

To maintain engineering accuracy without exaggerated claims, here is the explicit breakdown of what is formally guaranteed versus what depends on runtime and testing:

### ✅ Formally Guaranteed by Bend's Type System
- **Affine Resource Tracking**: Sockets and Listeners cannot be copied or duplicated. They are threaded linearly through functions.
- **Memory Safety & Data Race Freedom in Pure Code**: Pure Bend functions (`parse_and_route`, `parse_headers`, `build_response`, etc.) operate on immutable interaction net trees with zero shared mutable state.

### ✅ Structurally Guaranteed by Pure Code Design
- **No Parser Panics or Crashes**: The pure parsing pipeline is total over all string inputs; it never throws unhandled exceptions or crashes. Any malformed string maps deterministically to a controlled error response (`400`, `404`, `405`, `413`, `431`).
- **Exact UTF-8 Content-Length**: `string_utf8_len` calculates the exact octet count of the response body across all unicode ranges (ASCII, 2-byte, 3-byte, and 4-byte surrogate pairs), guaranteeing that `Content-Length` matches actual transmitted bytes.

### 🧪 Verified by Test Suites (Empirical Assurance)
- **TCP Fragmentation Handling**: Validated by streaming requests byte-by-byte (1-byte trickle sends) and splitting headers across TCP packet boundaries.
- **Request Smuggling Resistance**: Validated by tests for duplicate `Content-Length` and `Transfer-Encoding` permutations.
- **Fuzzing Resilience**: Validated against 90+ randomized byte streams, null bytes, and mutated verbs.

### ⚠️ NOT Formally Guaranteed by `@unsafe` Functions
- **Termination of Event Loops**: The main `serve` listener loop and the connection `read_headers_loop` cannot be proven to terminate by the Bend compiler. Termination of the read loop relies on dynamic fuel decrements and read timeouts rather than structural induction.

### ⚠️ NOT Guaranteed Due to OS, TCP, and Runtime Limits
- **OS Resource Exhaustion**: If the OS runs out of file descriptors, incoming TCP handshakes may fail at the kernel level.
- **Distributed Denial of Service (DDoS)**: Volumetric network saturation or SYN flood attacks must be handled at the firewall/load-balancer level, as user-space Bend cannot prevent kernel-level resource starvation.
- **No TLS / HTTPS**: This server speaks cleartext HTTP/1.1; TLS termination should be provided by an external reverse proxy (e.g., Caddy, NGINX) or Tailscale encryption.

---

## License

MIT License.

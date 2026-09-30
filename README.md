# Bend HTTP Web Server

A concurrent HTTP/1.1 web server implemented from scratch in **[Bend](https://bend-lang.com/)** (developed by HigherOrderCO).

Bend is a high-level, massively parallel, pure functional programming language powered by **Interaction Combinators** and the **HVM2** runtime.

This project demonstrates how to build a full-featured HTTP web server in pure Bend using the Bend 2.0 IO effect system (`Base` standard library's `TCP` module), handling concurrent client connections with green threads via `IO.spawn`.

---

## Features

- **Native TCP Socket Networking**:
  - Listens on `0.0.0.0:8080` (accessible via localhost, LAN, and Tailscale / Tailnet).
  - Uses Bend 2.0 TCP effects: `TCP.listen`, `TCP.accept`, `TCP.recv`, `TCP.send`, and `Socket.close`.
- **Concurrent Request Handling via `IO.spawn`**:
  - Spawns an isolated computation (green thread / fiber) for every incoming connection, providing non-blocking concurrent request handling.
- **Pure Functional Routing**:
  - Pattern matches on incoming HTTP request lines and prefixes to dynamically route requests to endpoints.
- **Affine Resource Safety**:
  - Leverages Bend's affine type system where handles like `Socket` and `Listener` cannot be leaked or discarded without explicit consumption.
- **Rich Endpoints**:
  - `GET /` — Interactive dark-themed HTML homepage.
  - `GET /hello` — Greetings page.
  - `GET /about` — Introduction to the Bend language and Interaction Combinators.
  - `GET /api` — JSON API response (`application/json`).
  - `*` — 404 Not Found error page.

---

## Project Structure

- [`server.bend`](server.bend) — The complete HTTP web server implementation written in Bend.
- [`start.sh`](start.sh) — Convenient startup shell script.
- [`test_client.py`](test_client.py) — Automated Python test suite verifying HTML, JSON, and 404 endpoints.
- [`README.md`](README.md) — Project documentation.

---

## Quick Start

### 1. Install Bend

If Bend is not already installed on your system:

```bash
curl -fsSL https://bend-lang.com/install.sh | sh
export PATH="$HOME/.bend/bin:$PATH"
```

### 2. Start the Server

```bash
cd /path/to/bend-web-server
./start.sh
```

Or run directly with the `bend` CLI:

```bash
bend server.bend
```

Sample output:
```text
========================================
  Bend Web Server is running on port 8080
  Local:     http://127.0.0.1:8080/
  Tailscale: http://100.104.204.50:8080/
========================================
[Bend-HTTP] GET / HTTP/1.1
[Bend-HTTP] GET /api HTTP/1.1
```

### 3. Send Requests

Open `http://localhost:8080/` in your browser, or use `curl`:

```bash
# HTML Homepage
curl -i http://127.0.0.1:8080/

# JSON API
curl -i http://127.0.0.1:8080/api

# Hello Endpoint
curl -i http://127.0.0.1:8080/hello

# 404 Not Found
curl -i http://127.0.0.1:8080/unknown
```

### 4. Run Automated Tests

With the server running, execute:

```bash
python3 test_client.py
```

---

## Architecture & Implementation Notes

### Concurrent Accept Loop (`IO.spawn`)

In Bend, server event loops that run indefinitely are marked with `@unsafe`:

```bend
def serve_next(m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, http_conn(s))
    return l

@unsafe
def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- serve_next(m)
    serve(l2)
```

Each connection is handed off to `IO.spawn(Unit, http_conn(s))` which runs concurrently without blocking the main listener loop.

### Request Handling & Affine Handle Threading

```bend
def http_handle_recv(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{+req}:
      resp = http_response(req)
      req_line = first_line(req)
      do IO<Unit>:
        Unit <- IO.print(String.append("[Bend-HTTP] ", req_line))
        sm : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, resp)
        http_close_after_send(sm)
    case Fail{e}:
      Socket.close(s)
```

Because socket handles are affine resources, operations thread the socket handle back (`(s, r)`), guaranteeing that sockets are explicitly closed in all execution branches.

---

## License

MIT License.

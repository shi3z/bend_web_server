# Bend Massively Parallel HTTP Web Server
# Built for Bend 2.0 (HigherOrderCO / https://bend-lang.com/)
import Base

def first_line_step(lines: List<&2, String>) -> String:
  match lines:
    case Nil{}:
      "EMPTY"
    case h <> t:
      h

def first_line(req: String) -> String:
  first_line_step(String.lines(req))

def route_not_found() -> String:
  "HTTP/1.1 404 Not Found\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!DOCTYPE html><html><head><meta charset='utf-8'><title>404 Not Found</title><style>body{font-family:sans-serif;max-width:600px;margin:50px auto;padding:20px;background:#1a1a1a;color:#eee}h1{color:#f44336}a{color:#64b5f6}</style></head><body><h1>404 Not Found</h1><p>The requested endpoint was not found on this Bend Web Server.</p><p><a href='/'>Return to Home</a></p></body></html>\n"

def route_api() -> String:
  "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nConnection: close\r\n\r\n{\"server\":\"Bend HTTP Server\",\"version\":\"2.0\",\"runtime\":\"Interaction Combinators\",\"language\":\"Bend\",\"features\":[\"massive parallelism\",\"pure functional\",\"affine types\",\"io effects\"]}\n"

def route_about() -> String:
  "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!DOCTYPE html><html><head><meta charset='utf-8'><title>About Bend</title><style>body{font-family:sans-serif;max-width:700px;margin:40px auto;padding:20px;line-height:1.6;background:#0d1117;color:#c9d1d9}h1{color:#ff7b72}a{color:#58a6ff;text-decoration:none}a:hover{text-decoration:underline}code{background:#21262d;padding:2px 6px;border-radius:4px;color:#ffa657}</style></head><body><h1>About Bend Language</h1><p>Bend is a high-level, massively parallel programming language developed by <strong>HigherOrderCO</strong>.</p><p>It runs on <strong>HVM2</strong> (Higher-order Virtual Machine) using Interaction Combinators, allowing effortless scaling across multi-core CPUs and GPUs without manual thread management.</p><p><a href='/'>← Back to Home</a></p></body></html>\n"

def route_hello() -> String:
  "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!DOCTYPE html><html><head><meta charset='utf-8'><title>Hello Bend</title><style>body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px;background:#0d1117;color:#c9d1d9}h1{color:#7ee787}a{color:#58a6ff}</style></head><body><h1>Hello from Bend! 👋</h1><p>This request was processed by a concurrent green thread in Bend using <code>IO.spawn</code>.</p><p><a href='/'>← Back to Home</a></p></body></html>\n"

def route_home() -> String:
  "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!DOCTYPE html><html lang='ja'><head><meta charset='utf-8'><title>Bend Web Server</title><style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;background:#0d1117;color:#c9d1d9;line-height:1.6}h1{color:#f78166;border-bottom:1px solid #30363d;padding-bottom:10px}h2{color:#79c0ff;margin-top:24px}.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;margin:20px 0}.btn{display:inline-block;padding:8px 16px;background:#238636;color:#fff;text-decoration:none;border-radius:6px;margin-right:10px;font-weight:bold}.btn:hover{background:#2ea043}.btn-alt{background:#21262d;border:1px solid #30363d;color:#58a6ff}.btn-alt:hover{background:#30363d}code{background:#21262d;padding:2px 6px;border-radius:4px;color:#f0883e;font-size:0.95em}footer{margin-top:40px;padding-top:15px;border-top:1px solid #30363d;color:#8b949e;font-size:0.9em}</style></head><body><h1>⚡ Bend Web Server</h1><div class='card'><h2>🚀 Server is Running!</h2><p>This web page was generated and served completely by an HTTP server written in <strong>Bend</strong> (the massively parallel language by HigherOrderCO).</p><ul><li>Native TCP socket binding via <code>TCP.listen</code></li><li>Non-blocking concurrent connection handling via <code>IO.spawn</code></li><li>Functional routing & pattern matching over HTTP request lines</li><li>Powered by Interaction Combinators</li></ul></div><div class='card'><h2>Explore Endpoints</h2><p><a class='btn btn-alt' href='/'>Home (/)</a><a class='btn btn-alt' href='/hello'>/hello</a><a class='btn btn-alt' href='/about'>/about</a><a class='btn' href='/api'>/api (JSON)</a></p></div><footer><p>Served by <strong>Bend 2.0</strong></p></footer></body></html>\n"

def route_step_home(is_home: Bool) -> String:
  match is_home:
    case True{}:
      route_home()
    case False{}:
      route_not_found()

def route_step_about(is_about: Bool, +req: String) -> String:
  match is_about:
    case True{}:
      route_about()
    case False{}:
      route_step_home(String.starts_with(req, "GET / HTTP"))

def route_step_hello(is_hello: Bool, +req: String) -> String:
  match is_hello:
    case True{}:
      route_hello()
    case False{}:
      route_step_about(String.starts_with(req, "GET /about"), req)

def route_step_api(is_api: Bool, +req: String) -> String:
  match is_api:
    case True{}:
      route_api()
    case False{}:
      route_step_hello(String.starts_with(req, "GET /hello"), req)

def http_response(+req: String) -> String:
  route_step_api(String.starts_with(req, "GET /api"), req)

def http_close_after_send(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

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

def http_conn(s: Socket) -> IO(Unit):
  do IO<Unit>:
    rm : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 4096)
    http_handle_recv(rm)

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

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("0.0.0.0", 8080))
    Unit <- IO.print("========================================")
    Unit <- IO.print("  Bend Web Server is running on port 8080")
    Unit <- IO.print("  Local:     http://127.0.0.1:8080/")
    Unit <- IO.print("  Tailscale: http://100.104.204.50:8080/")
    Unit <- IO.print("========================================")
    serve(l)

# Robust Bend HTTP Web Server
import Base

# ==============================================================================
# SECTION 1: Pure HTTP Response Builder
# ==============================================================================

def concat_headers(s_line: String, c_type: String, c_len: String, +body: String) -> String:
  String.append(s_line,
    String.append("\r\nContent-Type: ",
      String.append(c_type,
        String.append("\r\nContent-Length: ",
          String.append(c_len,
            String.append("\r\nConnection: close\r\nServer: Bend-HTTP/2.0\r\n\r\n", body))))))

def char_byte_len_step4(is_4: Bool) -> Nat:
  match is_4:
    case True{}:
      4n
    case False{}:
      3n

def char_byte_len_step3(is_3_or_4: Bool, +code: U32) -> Nat:
  match is_3_or_4:
    case True{}:
      char_byte_len_step4(U32.is_ge(code, 65536))
    case False{}:
      2n

def char_byte_len_step2(is_multi: Bool, +code: U32) -> Nat:
  match is_multi:
    case True{}:
      char_byte_len_step3(U32.is_ge(code, 2048), code)
    case False{}:
      1n

def char_byte_len(c: Char) -> Nat:
  match c:
    case Chr{+x}:
      char_byte_len_step2(U32.is_ge(x, 128), x)

def string_utf8_len(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{h, t}:
      Nat.add(char_byte_len(h), string_utf8_len(t))

def build_response(code: String, reason: String, c_type: String, +body: String) -> String:
  c_len = Nat.show(string_utf8_len(body))
  s_line = String.append("HTTP/1.1 ", String.append(code, String.append(" ", reason)))
  concat_headers(s_line, c_type, c_len, body)

def resp_200(c_type: String, body: String) -> String:
  build_response("200", "OK", c_type, body)

def resp_400() -> String:
  build_response("400", "Bad Request", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>400 Bad Request</title></head><body><h1>400 Bad Request</h1><p>Invalid HTTP request syntax or prohibited headers.</p></body></html>\n")

def resp_404() -> String:
  build_response("404", "Not Found", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1><p>The requested endpoint does not exist.</p></body></html>\n")

def resp_405() -> String:
  build_response("405", "Method Not Allowed", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>405 Method Not Allowed</title></head><body><h1>405 Method Not Allowed</h1><p>Only the GET method is allowed on this server.</p></body></html>\n")

def resp_408() -> String:
  build_response("408", "Request Timeout", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>408 Request Timeout</title></head><body><h1>408 Request Timeout</h1><p>The client took too long or exceeded maximum read iterations.</p></body></html>\n")

def resp_413() -> String:
  build_response("413", "Payload Too Large", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>413 Payload Too Large</title></head><body><h1>413 Payload Too Large</h1><p>Request payload exceeds maximum allowed size (64KB).</p></body></html>\n")

def resp_431() -> String:
  build_response("431", "Request Header Fields Too Large", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>431 Request Header Fields Too Large</title></head><body><h1>431 Request Header Fields Too Large</h1><p>Header fields exceed maximum allowed size (16KB).</p></body></html>\n")

def resp_500() -> String:
  build_response("500", "Internal Server Error", "text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><title>500 Internal Server Error</title></head><body><h1>500 Internal Server Error</h1><p>An unexpected server error occurred.</p></body></html>\n")

def resp_home() -> String:
  resp_200("text/html; charset=utf-8",
    "<!DOCTYPE html><html lang=\"ja\"><head><meta charset=\"utf-8\"><title>Bend Web Server</title><style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;background:#0d1117;color:#c9d1d9;line-height:1.6}h1{color:#f78166;border-bottom:1px solid #30363d;padding-bottom:10px}h2{color:#79c0ff;margin-top:24px}.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;margin:20px 0}.btn{display:inline-block;padding:8px 16px;background:#238636;color:#fff;text-decoration:none;border-radius:6px;margin-right:10px;font-weight:bold}.btn:hover{background:#2ea043}.btn-alt{background:#21262d;border:1px solid #30363d;color:#58a6ff}code{background:#21262d;padding:2px 6px;border-radius:4px;color:#f0883e}footer{margin-top:40px;padding-top:15px;border-top:1px solid #30363d;color:#8b949e}</style></head><body><h1>⚡ Bend Web Server</h1><div class=\"card\"><h2>🚀 Robust & Secure HTTP Server</h2><p>This web server is written in <strong>Bend</strong> (Interaction Combinators / HVM2) with strict HTTP parsing, header validation, and connection error resilience.</p><ul><li>Header size & body size limits (DoS mitigation)</li><li>Exact route matching (no naive prefix match)</li><li>Full CRLF & header validation (smuggling protection)</li><li>Affine resource tracking & leak-free socket lifecycle</li></ul></div><div class=\"card\"><h2>Endpoints</h2><p><a class=\"btn btn-alt\" href=\"/\">Home (/)</a><a class=\"btn btn-alt\" href=\"/hello\">/hello</a><a class=\"btn btn-alt\" href=\"/about\">/about</a><a class=\"btn\" href=\"/api\">/api (JSON)</a></p></div><footer><p>Powered by <strong>Bend 2.0</strong></p></footer></body></html>\n")

def resp_hello() -> String:
  resp_200("text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Hello Bend</title><style>body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px;background:#0d1117;color:#c9d1d9}h1{color:#7ee787}a{color:#58a6ff}</style></head><body><h1>Hello from Bend! 👋</h1><p>Request processed safely by a green thread in Bend.</p><p><a href=\"/\">← Back to Home</a></p></body></html>\n")

def resp_about() -> String:
  resp_200("text/html; charset=utf-8",
    "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>About Bend</title><style>body{font-family:sans-serif;max-width:700px;margin:40px auto;padding:20px;line-height:1.6;background:#0d1117;color:#c9d1d9}h1{color:#ff7b72}a{color:#58a6ff}</style></head><body><h1>About Bend Language</h1><p>Bend is a massively parallel, high-level functional programming language designed by HigherOrderCO.</p><p><a href=\"/\">← Back to Home</a></p></body></html>\n")

def resp_api() -> String:
  resp_200("application/json; charset=utf-8",
    "{\"server\":\"Bend HTTP Server\",\"version\":\"2.0\",\"runtime\":\"Interaction Combinators\",\"language\":\"Bend\",\"features\":[\"massive parallelism\",\"pure functional\",\"affine types\",\"io effects\",\"robust http parser\"]}\n")

# ==============================================================================
# SECTION 2: Exact Route Matching
# ==============================================================================

def route_path_step_api(is_api: Bool) -> String:
  match is_api:
    case True{}:
      resp_api()
    case False{}:
      resp_404()

def route_path_step_about(is_about: Bool, +path: String) -> String:
  match is_about:
    case True{}:
      resp_about()
    case False{}:
      route_path_step_api(String.eq(path, "/api"))

def route_path_step_hello(is_hello: Bool, +path: String) -> String:
  match is_hello:
    case True{}:
      resp_hello()
    case False{}:
      route_path_step_about(String.eq(path, "/about"), path)

def route_path_step_home(is_home: Bool, +path: String) -> String:
  match is_home:
    case True{}:
      resp_home()
    case False{}:
      route_path_step_hello(String.eq(path, "/hello"), path)

def route_path(+path: String) -> String:
  route_path_step_home(String.eq(path, "/"), path)

# ==============================================================================
# SECTION 3: Pure Request Line & Header Parsing
# ==============================================================================

def drop_cr_step(s: String, has_cr: Bool) -> String:
  match has_cr:
    case True{}:
      String.reverse(String.drop(String.reverse(s), 1n))
    case False{}:
      s

def strip_cr(+s: String) -> String:
  drop_cr_step(s, String.ends_with(s, "\r"))

def strip_all_cr(lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case h <> t:
      strip_cr(h) <> strip_all_cr(t)

def get_path_head(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}:
      ""
    case p <> t:
      p

def extract_path(target: String) -> String:
  get_path_head(String.split(target, Chr{63}))

def is_known_non_get(+method: String) -> Bool:
  Bool.or(String.eq(method, "POST"),
    Bool.or(String.eq(method, "PUT"),
      Bool.or(String.eq(method, "DELETE"),
        Bool.or(String.eq(method, "HEAD"),
          Bool.or(String.eq(method, "OPTIONS"),
            String.eq(method, "PATCH"))))))

type HState is Data:
  HState{
    has_cl: Bool,
    cl_val: U32,
    has_te: Bool,
    invalid: Bool,
    too_large: Bool
  }

def check_hval_num_step(is_gt: Bool, n: U32, has_te: Bool, too_large: Bool) -> HState:
  match is_gt:
    case True{}:
      HState{True{}, n, has_te, False{}, True{}}
    case False{}:
      HState{True{}, n, has_te, False{}, too_large}

def check_hval_num(+n: U32, has_te: Bool, too_large: Bool) -> HState:
  check_hval_num_step(U32.is_gt(n, 65536), n, has_te, too_large)

def check_hval_read(m: Maybe<&2, U32>, has_te: Bool, too_large: Bool) -> HState:
  match m:
    case None{}:
      HState{True{}, 0, has_te, True{}, too_large}
    case Some{n}:
      check_hval_num(n, has_te, too_large)

def check_cl_step(has_cl: Bool, cl_val: U32, has_te: Bool, too_large: Bool, val: String) -> HState:
  match has_cl:
    case True{}:
      HState{True{}, cl_val, has_te, True{}, too_large}
    case False{}:
      check_hval_read(U32.read(val), has_te, too_large)

def check_header_is_cl(is_cl: Bool, val: String, has_cl: Bool, cl_val: U32, has_te: Bool, too_large: Bool) -> HState:
  match is_cl:
    case True{}:
      check_cl_step(has_cl, cl_val, has_te, too_large, val)
    case False{}:
      HState{has_cl, cl_val, has_te, False{}, too_large}

def check_header_is_te(is_te: Bool, name: String, val: String, has_cl: Bool, cl_val: U32, has_te_old: Bool, too_large: Bool) -> HState:
  match is_te:
    case True{}:
      HState{has_cl, cl_val, True{}, False{}, too_large}
    case False{}:
      check_header_is_cl(String.eq(name, "content-length"), val, has_cl, cl_val, has_te_old, too_large)

def check_header_name(+name: String, val: String, has_cl: Bool, cl_val: U32, has_te: Bool, too_large: Bool) -> HState:
  check_header_is_te(String.eq(name, "transfer-encoding"), name, val, has_cl, cl_val, has_te, too_large)

def check_header_parts(hparts: List<&2, String>, has_cl: Bool, cl_val: U32, has_te: Bool, too_large: Bool) -> HState:
  match hparts:
    case Nil{}:
      HState{has_cl, cl_val, has_te, True{}, too_large}
    case hname <> hvals:
      name = String.to_lower(String.trim(hname))
      val = String.trim(String.concat(hvals))
      check_header_name(name, val, has_cl, cl_val, has_te, too_large)

def check_header_line_has_colon(has_colon: Bool, +line: String, has_cl: Bool, cl_val: U32, has_te: Bool, too_large: Bool) -> HState:
  match has_colon:
    case False{}:
      HState{has_cl, cl_val, has_te, True{}, too_large}
    case True{}:
      check_header_parts(String.split(line, Chr{58}), has_cl, cl_val, has_te, too_large)

def check_header_line(+line: String, st: HState) -> HState:
  match st:
    case HState{+has_cl, +cl_val, +has_te, +invalid, +too_large}:
      match invalid:
        case True{}:
          HState{has_cl, cl_val, has_te, True{}, too_large}
        case False{}:
          check_header_line_has_colon(String.contains(line, ":"), line, has_cl, cl_val, has_te, too_large)

def parse_headers_clean(lines: List<&2, String>, st: HState) -> HState:
  match lines:
    case Nil{}:
      st
    case h <> t:
      match h:
        case SNil{}:
          st
        case SCon{ch, ct}:
          parse_headers_clean(t, check_header_line(SCon{ch, ct}, st))

def parse_headers(lines: List<&2, String>) -> HState:
  parse_headers_clean(lines, HState{False{}, 0, False{}, False{}, False{}})

def check_hstate_cl_step(has_body: Bool, path: String) -> String:
  match has_body:
    case True{}:
      resp_400()
    case False{}:
      route_path(path)

def check_hstate_cl(has_cl: Bool, cl_val: U32, path: String) -> String:
  match has_cl:
    case True{}:
      check_hstate_cl_step(U32.is_gt(cl_val, 0), path)
    case False{}:
      route_path(path)

def check_hstate_te(has_te: Bool, has_cl: Bool, cl_val: U32, path: String) -> String:
  match has_te:
    case True{}:
      resp_400()
    case False{}:
      check_hstate_cl(has_cl, cl_val, path)

def check_hstate_large(too_large: Bool, has_te: Bool, has_cl: Bool, cl_val: U32, path: String) -> String:
  match too_large:
    case True{}:
      resp_413()
    case False{}:
      check_hstate_te(has_te, has_cl, cl_val, path)

def check_hstate_inv(invalid: Bool, too_large: Bool, has_te: Bool, has_cl: Bool, cl_val: U32, path: String) -> String:
  match invalid:
    case True{}:
      resp_400()
    case False{}:
      check_hstate_large(too_large, has_te, has_cl, cl_val, path)

def parse_parts_headers_step(st: HState, path: String) -> String:
  match st:
    case HState{has_cl, cl_val, has_te, invalid, too_large}:
      check_hstate_inv(invalid, too_large, has_te, has_cl, cl_val, path)

def parse_parts_headers(path: String, rest_lines: List<&2, String>) -> String:
  parse_parts_headers_step(parse_headers(rest_lines), path)

def check_target_slash(is_slash: Bool, target: String, rest_lines: List<&2, String>) -> String:
  match is_slash:
    case True{}:
      path = extract_path(target)
      parse_parts_headers(path, rest_lines)
    case False{}:
      resp_400()

def parse_parts_target(+target: String, rest_lines: List<&2, String>) -> String:
  check_target_slash(String.starts_with(target, "/"), target, rest_lines)

def check_method_known(is_known: Bool) -> String:
  match is_known:
    case True{}:
      resp_405()
    case False{}:
      resp_400()

def check_method_get(is_get: Bool, method: String, target: String, rest_lines: List<&2, String>) -> String:
  match is_get:
    case True{}:
      parse_parts_target(target, rest_lines)
    case False{}:
      check_method_known(is_known_non_get(method))

def parse_parts_method(+method: String, target: String, rest_lines: List<&2, String>) -> String:
  check_method_get(String.eq(method, "GET"), method, target, rest_lines)

def check_ver_10(is_10: Bool, method: String, target: String, rest_lines: List<&2, String>) -> String:
  match is_10:
    case True{}:
      parse_parts_method(method, target, rest_lines)
    case False{}:
      resp_400()

def check_ver_11(is_11: Bool, version: String, method: String, target: String, rest_lines: List<&2, String>) -> String:
  match is_11:
    case True{}:
      parse_parts_method(method, target, rest_lines)
    case False{}:
      check_ver_10(String.eq(version, "HTTP/1.0"), method, target, rest_lines)

def parse_parts_ver(version: String, method: String, target: String, rest_lines: List<&2, String>) -> String:
  +v = version
  check_ver_11(String.eq(v, "HTTP/1.1"), v, method, target, rest_lines)

def check_parts_empty_tail(is_empty: Bool, method: String, target: String, version: String, rest_lines: List<&2, String>) -> String:
  match is_empty:
    case True{}:
      parse_parts_ver(version, method, target, rest_lines)
    case False{}:
      resp_400()

def check_parts_rest(tail: List<&2, String>, method: String, target: String, version: String, rest_lines: List<&2, String>) -> String:
  match tail:
    case Nil{}:
      parse_parts_ver(version, method, target, rest_lines)
    case h <> t:
      check_parts_empty_tail(String.is_empty(String.trim(h)), method, target, version, rest_lines)

def check_parts_2(p2: List<&2, String>, method: String, target: String, rest_lines: List<&2, String>) -> String:
  match p2:
    case Nil{}:
      resp_400()
    case version <> p3:
      check_parts_rest(p3, method, target, version, rest_lines)

def check_parts_1(p1: List<&2, String>, method: String, rest_lines: List<&2, String>) -> String:
  match p1:
    case Nil{}:
      resp_400()
    case target <> p2:
      check_parts_2(p2, method, target, rest_lines)

def parse_req_line_parts(parts: List<&2, String>, rest_lines: List<&2, String>) -> String:
  match parts:
    case Nil{}:
      resp_400()
    case method <> p1:
      check_parts_1(p1, method, rest_lines)

def parse_req_line(line: String, rest_lines: List<&2, String>) -> String:
  parse_req_line_parts(String.split(line, Chr{32}), rest_lines)

def parse_request_step(lines: List<&2, String>) -> String:
  match lines:
    case Nil{}:
      resp_400()
    case h <> t:
      match h:
        case SNil{}:
          parse_request_step(t)
        case SCon{ch, ct}:
          parse_req_line(SCon{ch, ct}, t)

def parse_and_route(raw: String) -> String:
  parse_request_step(strip_all_cr(String.lines(raw)))

# ==============================================================================
# SECTION 4: I/O Connection Layer (Socket Lifecycle & DoS Protection)
# ==============================================================================

def close_after_send(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def send_response_and_close(s: Socket, resp: String) -> IO(Unit):
  do IO<Unit>:
    sm : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, resp)
    close_after_send(sm)

# @unsafe justification: Recursive socket read loop with timeout & fuel decrement.
@unsafe
def read_poll_step(
  s: Socket,
  r: Result<&1, &1, U32 & String, Maybe<&1, String>>,
  buf: String,
  p: Nat
) -> IO(Unit):
  match r:
    case Done{opt}:
      match opt:
        case None{}:
          # Client read timeout (5000ms elapsed without data)
          Socket.close(s)
        case Some{chunk}:
          match chunk:
            case SNil{}:
              # EOF: Peer closed connection prematurely
              Socket.close(s)
            case SCon{ch, ct}:
              read_headers_loop(s, String.append(buf, SCon{ch, ct}), p)
    case Fail{e}:
      # TCP read error on socket
      Socket.close(s)

@unsafe
def read_poll_unpack(
  pm: Socket & Result<&1, &1, U32 & String, Maybe<&1, String>>,
  buf: String,
  p: Nat
) -> IO(Unit):
  (s2, r) = pm
  read_poll_step(s2, r, buf, p)

@unsafe
def read_headers_poll(s: Socket, buf: String, p: Nat) -> IO(Unit):
  do IO<Unit>:
    pm : Socket & Result<&1, &1, U32 & String, Maybe<&1, String>> <- TCP.poll(s, 2048, 5000)
    read_poll_unpack(pm, buf, p)

@unsafe
def read_headers_check_fuel(s: Socket, buf: String, fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      # Exceeded maximum read iterations (slowloris mitigation)
      send_response_and_close(s, resp_408())
    case 1n+p:
      read_headers_poll(s, buf, p)

@unsafe
def read_headers_check_large(is_large: Bool, s: Socket, buf: String, fuel: Nat) -> IO(Unit):
  match is_large:
    case True{}:
      # Header fields exceeded 16KB limit
      send_response_and_close(s, resp_431())
    case False{}:
      read_headers_check_fuel(s, buf, fuel)

@unsafe
def read_headers_check_end(has_end: Bool, s: Socket, +buf: String, fuel: Nat) -> IO(Unit):
  match has_end:
    case True{}:
      resp = parse_and_route(buf)
      send_response_and_close(s, resp)
    case False{}:
      read_headers_check_large(Nat.is_ge(String.length(buf), 16384n), s, buf, fuel)

@unsafe
def read_headers_loop(s: Socket, +buf: String, fuel: Nat) -> IO(Unit):
  has_end = Bool.or(String.contains(buf, "\r\n\r\n"), String.contains(buf, "\n\n"))
  read_headers_check_end(has_end, s, buf, fuel)

def handle_client(s: Socket) -> IO(Unit):
  read_headers_loop(s, "", 64n)

# ==============================================================================
# SECTION 5: Server Event Loop (Resilient Accept)
# ==============================================================================

# Recovers from connection-level accept failures without crashing the listener loop
def serve_accept_step(l: Listener, r: Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match r:
    case Done{s}:
      do IO<Listener>:
        IO.spawn(Unit, handle_client(s))
        return l
    case Fail{e}:
      do IO<Listener>:
        Unit <- IO.print("[Bend-HTTP] Recoverable accept error encountered; continuing...")
        return l

def serve_next(m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  serve_accept_step(l, r)

# @unsafe justification: Infinite accept loop.
@unsafe
def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- serve_next(m)
    serve(l2)

# @unsafe justification: Calls infinite serve loop.
@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("0.0.0.0", 8080))
    Unit <- IO.print("========================================")
    Unit <- IO.print("  Bend Robust HTTP Server on port 8080  ")
    Unit <- IO.print("  Local:     http://127.0.0.1:8080/     ")
    Unit <- IO.print("  Tailscale: http://100.104.204.50:8080/ ")
    Unit <- IO.print("========================================")
    serve(l)

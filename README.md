# Bend Web Server (HTTP サーバー)

[Bend](https://bend-lang.com/)（HigherOrderCO 開発）で実装された並行 HTTP Web サーバーです。

Bend は相互作用コンビネータ（Interaction Combinators）と **HVM2**（Higher-order Virtual Machine）を基盤とする、超並列・高水準関数型言語です。

本プロジェクトは、Bend 2.0 の最新 IO エフェクトシステム（`Base` ライブラリの `TCP` モジュール）を活用し、完全な HTTP/1.1 Web サーバーをピュアな Bend 言語で実装しています。

---

## 🌟 特徴

1. **ネイティブ TCP ソケット対応**:
   - `TCP.listen("127.0.0.1", 8080)` でソケットをバインド＆リッスン。
   - `TCP.accept`、`TCP.recv`、`TCP.send`、`Socket.close` による通信制御。
2. **`IO.spawn` による非同期・並行クライアント処理**:
   - 接続を受信するたびに `IO.spawn` で独立した計算（グリーンファイバー）を立ち上げ、並行にリクエストを処理します。
3. **関数型パターンマッチングによる HTTP ルーティング**:
   - リクエスト行のプレフィックスをマッチングし、パスに応じたレスポンスを生成。
4. **アフィン型（Affine Types）によるリソース安全管理**:
   - `Socket` や `Listener` のハンドルは複製不可・消費必須（Linear/Affine）として型システムで厳密に追跡され、リークを防止。
5. **リッチなエンドポイント**:
   - `/` : スタイリッシュなダークテーマの HTML ホームページ
   - `/hello` : メッセージ表示ページ
   - `/about` : Bend 言語の解説ページ
   - `/api` : JSON レスポンス API (`application/json`)
   - `*` : 404 Not Found ページ

---

## 📂 ディレクトリ構成

- [`server.bend`](server.bend): Bend で書かれた Web サーバーの本体実装
- [`start.sh`](start.sh): サーバーの起動シェルスクリプト
- [`test_client.py`](test_client.py): 各エンドポイント（HTML, JSON, 404）を検証するテストクライアント

---

## 🚀 クイックスタート

### 1. Bend のインストール

Bend が未インストールの場合は、公式インストーラーを実行します:

```bash
curl -fsSL https://bend-lang.com/install.sh | sh
export PATH="$HOME/.bend/bin:$PATH"
```

### 2. サーバーの起動

```bash
cd /home/shi3z/bend-web-server
./start.sh
```

または直接 `bend` コマンドで起動:

```bash
bend server.bend
```

出力例:
```text
========================================
  Bend Web Server is running on port 8080
  Access: http://127.0.0.1:8080/
========================================
[Bend-HTTP] GET / HTTP/1.1
[Bend-HTTP] GET /api HTTP/1.1
```

### 3. ブラウザや curl でアクセス

ブラウザで `http://127.0.0.1:8080/` にアクセスするか、curl でリクエストを送信します:

```bash
# ホームページ (HTML)
curl -i http://127.0.0.1:8080/

# JSON API
curl -i http://127.0.0.1:8080/api

# Hello ページ
curl -i http://127.0.0.1:8080/hello

# 存在しないパス (404)
curl -i http://127.0.0.1:8080/unknown
```

### 4. 自動テストの実行

サーバーを起動した状態で、別ターミナルからテストを実行します:

```bash
python3 test_client.py
```

---

## 🔬 実装の詳細解説

### 1. TCP ソケットの受信ループ

Bend では停止しないサーバーの無限ループは `@unsafe` デコレータを付与して再帰させます:

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

### 2. リクエストの受信とレスポンス送信

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

`Done{+req}` のように `+` アノテーションを付与することで、`String`（Data カインド）の複製を許可し、ルーティング関数とログ表示の両方に渡しています。

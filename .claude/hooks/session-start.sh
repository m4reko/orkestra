#!/bin/bash
# Repairs the Claude Code on the web sandbox so `gleam test`/`gleam run` work.
# No-op outside the remote sandbox.
#
# Three sandbox quirks this script works around:
#   1. asdf shims for `gleam` exec themselves recursively (CPU spin, no output).
#   2. The egress proxy MITMs TLS with an Anthropic CA that's in the system
#      trust store but not in rebar3's bundled `certifi` (Mozilla bundle).
#   3. OTP `httpc` sends `content-length: 0` and an empty `te:` header on GETs
#      with no body, which the egress Envoy rejects with HTTP 503.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SYSTEM_CACERTS=/etc/ssl/certs/ca-certificates.crt

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GLEAM_CACERTS_PATH=$SYSTEM_CACERTS" >> "$CLAUDE_ENV_FILE"
fi

# 1. Replace the recursive `gleam` shim with one that calls the real binary.
GLEAM_BIN="$(find /root/.asdf/installs/gleam -name gleam -type f -executable 2>/dev/null | head -1 || true)"
GLEAM_SHIM=/root/.asdf/shims/gleam
if [ -n "$GLEAM_BIN" ] && [ -e "$GLEAM_SHIM" ] && grep -q "exec $GLEAM_SHIM" "$GLEAM_SHIM" 2>/dev/null; then
  cat > "$GLEAM_SHIM" <<EOF
#!/bin/sh
export GLEAM_CACERTS_PATH="\${GLEAM_CACERTS_PATH:-$SYSTEM_CACERTS}"
exec "$GLEAM_BIN" "\$@"
EOF
  chmod +x "$GLEAM_SHIM"
  echo "session-start: fixed gleam shim -> $GLEAM_BIN"
fi

# 2. Patch rebar3's bundled certifi.beam to use system CAs instead of Mozilla's.
REBAR_BIN="$(find /root/.asdf/installs/rebar -name rebar3 -type f 2>/dev/null | head -1 || true)"
if [ -n "$REBAR_BIN" ] && ! [ -f "$REBAR_BIN.cert-patched" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  cat > "$TMP/certifi.erl" <<'CERT_EOF'
-module(certifi).
-export([cacerts/0, cacertfile/0]).
cacertfile() -> "/etc/ssl/certs/ca-certificates.crt".
cacerts() ->
    {ok, Bin} = file:read_file(cacertfile()),
    [Der || {'Certificate', Der, not_encrypted} <- public_key:pem_decode(Bin)].
CERT_EOF
  ( cd "$TMP" && erlc certifi.erl )
  ( cd "$TMP" && unzip -q "$REBAR_BIN" -d contents || [ $? -eq 1 ] )
  cp "$TMP/certifi.beam" "$TMP/contents/certifi/ebin/certifi.beam"
  ( cd "$TMP/contents" && zip -qr "$TMP/patched.zip" . )
  cat > "$TMP/header" <<'H_EOF'
#!/usr/bin/env escript
%% Rebar3 patched
%%! +sbtu +A1
H_EOF
  cat "$TMP/header" "$TMP/patched.zip" > "$REBAR_BIN.new"
  chmod +x "$REBAR_BIN.new"
  mv "$REBAR_BIN.new" "$REBAR_BIN"
  touch "$REBAR_BIN.cert-patched"
  rm -rf "$TMP"
  trap - EXIT
  echo "session-start: patched rebar3 certifi -> $REBAR_BIN"
fi

# 3. Patch OTP inets httpc_request to drop `content-length` and `te` from
#    empty-body requests (egress Envoy 503s on those headers).
INETS_DIR="$(find /usr/lib/erlang/lib -maxdepth 1 -type d -name 'inets-*' 2>/dev/null | head -1 || true)"
if [ -n "$INETS_DIR" ] && ! [ -f "$INETS_DIR/.httpc-patched" ]; then
  SRC="$INETS_DIR/src/http_client/httpc_request.erl"
  if [ -f "$SRC" ]; then
    TMP="$(mktemp -d)"
    python3 - "$SRC" "$TMP/httpc_request.erl" <<'PY_EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
old = 'post_data(_, Headers, _, []) ->\n    {Headers, ""};'
new = ('post_data(_, Headers, _, []) ->\n'
       '    {Headers#http_request_h{\'content-length\' = undefined, '
       '\'te\' = undefined}, ""};')
if old not in text:
    sys.exit("patch: anchor not found in " + src)
open(dst, 'w').write(text.replace(old, new, 1))
PY_EOF
    ( cd "$TMP" && erlc -I "$INETS_DIR/src/http_client" +debug_info httpc_request.erl )
    cp "$TMP/httpc_request.beam" "$INETS_DIR/ebin/httpc_request.beam"
    touch "$INETS_DIR/.httpc-patched"
    rm -rf "$TMP"
    echo "session-start: patched OTP httpc_request -> $INETS_DIR"
  fi
fi

# 4. Pre-fetch Gleam dependencies so the first build is fast.
export GLEAM_CACERTS_PATH="$SYSTEM_CACERTS"
gleam deps download 2>&1 | tail -3 || true

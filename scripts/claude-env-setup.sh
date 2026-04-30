#!/usr/bin/env bash
# Claude Code on the web — environment setup script.
#
# Paste the contents of this file into the "Setup script" field at
# claude.ai/code (Environment editor). It runs once per environment and the
# resulting filesystem state is cached, so subsequent sessions start instantly.
#
# Why this is needed:
#   - Anthropic's egress proxy intercepts HTTPS with its own CA chain. The
#     proxy CA is in /etc/ssl/certs/ca-certificates.crt, but Gleam's HTTP
#     client and rebar3's bundled `certifi` library don't read that file.
#   - Erlang's `httpc` sends `content-length: 0` and an empty `te:` header on
#     empty-body GETs, which the egress proxy rejects with HTTP 503.
#
# Without this script, `gleam test` fails because gleam can't fetch hex
# packages and rebar3 can't fetch the `pc` plugin needed by `esqlite`.

set -euo pipefail

SYSTEM_CACERTS=/etc/ssl/certs/ca-certificates.crt

# Make gleam/rebar3/erlc available in this script.
. /etc/profile.d/asdf.sh

# 1. Replace the asdf gleam shim with one that exports GLEAM_CACERTS_PATH and
#    execs the real binary directly. This avoids depending on env-var
#    inheritance and on `asdf exec` resolution for every invocation.
GLEAM_BIN="$(find /root/.asdf/installs/gleam -name gleam -type f -executable 2>/dev/null | head -1 || true)"
GLEAM_SHIM=/root/.asdf/shims/gleam
if [[ -n "$GLEAM_BIN" && -e "$GLEAM_SHIM" ]] && ! grep -q 'claude-wrapper' "$GLEAM_SHIM"; then
  cat > "$GLEAM_SHIM" <<EOF
#!/bin/sh
# claude-wrapper
export GLEAM_CACERTS_PATH="\${GLEAM_CACERTS_PATH:-$SYSTEM_CACERTS}"
exec "$GLEAM_BIN" "\$@"
EOF
  chmod +x "$GLEAM_SHIM"
  echo "Wrapped gleam shim -> $GLEAM_BIN"
fi

# 2. Patch the rebar3 escript's bundled certifi so it reads CAs from the
#    system bundle instead of its baked-in Mozilla snapshot (which doesn't
#    include the egress proxy's CA).
REBAR3="$(asdf which rebar3)"
PATCH_MARKER="${REBAR3}.claude-patched"

if [[ -f "$PATCH_MARKER" ]]; then
  echo "rebar3 already patched at $REBAR3"
else
  echo "Patching rebar3 at $REBAR3"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  ZIP_OFFSET=$(grep -aoP --byte-offset --max-count=1 $'PK\x03\x04' "$REBAR3" \
    | head -1 | cut -d: -f1)
  head -c "$ZIP_OFFSET" "$REBAR3" > "$TMP/header"
  tail -c +$((ZIP_OFFSET + 1)) "$REBAR3" > "$TMP/archive.zip"

  cat > "$TMP/certifi.erl" <<'ERL'
-module(certifi).
-export([cacerts/0, cacertfile/0]).
cacertfile() -> "/etc/ssl/certs/ca-certificates.crt".
cacerts() ->
    {ok, Bin} = file:read_file(cacertfile()),
    [Der || {'Certificate', Der, not_encrypted} <- public_key:pem_decode(Bin)].
ERL

  ( cd "$TMP" && erlc certifi.erl )

  mkdir -p "$TMP/zipfs/certifi/ebin"
  cp "$TMP/certifi.beam" "$TMP/zipfs/certifi/ebin/"
  ( cd "$TMP/zipfs" && zip -q "$TMP/archive.zip" certifi/ebin/certifi.beam )

  cat "$TMP/header" "$TMP/archive.zip" > "$REBAR3.tmp"
  chmod +x "$REBAR3.tmp"
  mv "$REBAR3.tmp" "$REBAR3"
  touch "$PATCH_MARKER"
  trap - EXIT
  rm -rf "$TMP"
  echo "rebar3 certifi patched."
fi

# 3. Patch OTP `inets`' httpc_request module to drop `content-length: 0` and
#    empty `te:` headers from empty-body requests. This fixes every Erlang
#    HTTP client at once (rebar3's hex client, gleam_httpc, etc.).
INETS_DIR="$(find /usr/lib/erlang/lib -maxdepth 1 -type d -name 'inets-*' 2>/dev/null | head -1 || true)"
HTTPC_MARKER="$INETS_DIR/.claude-httpc-patched"

if [[ -n "$INETS_DIR" && ! -f "$HTTPC_MARKER" ]]; then
  SRC="$INETS_DIR/src/http_client/httpc_request.erl"
  if [[ -f "$SRC" ]]; then
    echo "Patching OTP httpc_request at $INETS_DIR"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT

    python3 - "$SRC" "$TMP/httpc_request.erl" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
old = 'post_data(_, Headers, _, []) ->\n    {Headers, ""};'
new = ('post_data(_, Headers, _, []) ->\n'
       '    {Headers#http_request_h{\'content-length\' = undefined, '
       '\'te\' = undefined}, ""};')
if old not in text:
    sys.exit("patch anchor not found in " + src)
open(dst, 'w').write(text.replace(old, new, 1))
PY

    ( cd "$TMP" && erlc -I "$INETS_DIR/src/http_client" +debug_info httpc_request.erl )
    cp "$TMP/httpc_request.beam" "$INETS_DIR/ebin/httpc_request.beam"
    touch "$HTTPC_MARKER"
    trap - EXIT
    rm -rf "$TMP"
    echo "OTP httpc patched."
  fi
fi

echo "Environment setup complete."

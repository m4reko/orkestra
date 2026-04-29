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
#   - rebar3's HTTP adapter sends an empty `te:` header, which the egress
#     proxy rejects with HTTP 503 "upstream connect error".
#
# Without this script, `gleam test` fails because (a) gleam can't fetch hex
# packages, and (b) rebar3 can't fetch the `pc` plugin needed by the
# `esqlite` NIF dep.

set -euo pipefail

SYSTEM_CACERTS=/etc/ssl/certs/ca-certificates.crt

# 1. Persist GLEAM_CACERTS_PATH for future sessions. PAM reads /etc/environment
#    at login, so vars added here are inherited by the Claude process.
if ! grep -q '^GLEAM_CACERTS_PATH=' /etc/environment; then
  echo "GLEAM_CACERTS_PATH=$SYSTEM_CACERTS" >> /etc/environment
fi

# 2. Make gleam/rebar3/erlc available in this script.
. /etc/profile.d/asdf.sh
export GLEAM_CACERTS_PATH="$SYSTEM_CACERTS"

# 3. Patch the rebar3 escript: replace certifi (so it reads system CAs) and
#    rebar_httpc_adapter (so it sends `te: trailers`).
REBAR3="$(asdf which rebar3)"
PATCH_MARKER="${REBAR3}.claude-patched"

if [[ -f "$PATCH_MARKER" ]]; then
  echo "rebar3 already patched at $REBAR3"
else
  echo "Patching rebar3 at $REBAR3"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  # Slice off the escript shebang/header and isolate the embedded zip.
  ZIP_OFFSET=$(grep -aoP --byte-offset --max-count=1 $'PK\x03\x04' "$REBAR3" \
    | head -1 | cut -d: -f1)
  head -c "$ZIP_OFFSET" "$REBAR3" > "$TMP/header"
  tail -c +$((ZIP_OFFSET + 1)) "$REBAR3" > "$TMP/archive.zip"

  # Replacement certifi: read CAs from the system bundle instead of the
  # baked-in Mozilla snapshot (which doesn't include Anthropic's proxy CA).
  cat > "$TMP/certifi.erl" <<'ERL'
-module(certifi).
-export([cacerts/0, cacertfile/0]).
cacertfile() -> "/etc/ssl/certs/ca-certificates.crt".
cacerts() ->
    {ok, Bin} = file:read_file(cacertfile()),
    [Der || {'Certificate', Der, not_encrypted} <- public_key:pem_decode(Bin)].
ERL

  # Replacement HTTP adapter: same behavior as upstream but always injects
  # `te: trailers` so the egress proxy doesn't 503 on an empty `te:` header.
  cat > "$TMP/rebar_httpc_adapter.erl" <<'ERL'
-module(rebar_httpc_adapter).
-export([request/5]).
request(Method, URI, ReqHeaders, Body, AdapterConfig) ->
    Profile = maps:get(profile, AdapterConfig, default),
    DefaultHttpOpts = [{ssl, [{verify, verify_peer},
                              {cacerts, public_key:cacerts_get()}]}],
    HttpOpts = maps:get(http_options, AdapterConfig, DefaultHttpOpts),
    Opts = [{body_format, binary}],
    HeadersWithTE = maps:put(<<"te">>, <<"trailers">>, ReqHeaders),
    Headers = maps:fold(fun(K, V, Acc) ->
        [{binary_to_list(K), binary_to_list(V)} | Acc]
    end, [], HeadersWithTE),
    URIs = case URI of
        B when is_binary(B) -> binary_to_list(B);
        L -> L
    end,
    Request = case Body of
        undefined -> {URIs, Headers};
        {ContentType, B2} -> {URIs, Headers, binary_to_list(ContentType), B2};
        _ -> {URIs, Headers}
    end,
    case httpc:request(Method, Request, HttpOpts, Opts, Profile) of
        {ok, {{_, Status, _}, RespHeaders, RespBody}} ->
            Hs = lists:foldl(fun({K, V}, Acc) ->
                maps:put(list_to_binary(K), list_to_binary(V), Acc)
            end, #{}, RespHeaders),
            {ok, {Status, Hs, RespBody}};
        Error -> Error
    end.
ERL

  ( cd "$TMP" && erlc certifi.erl rebar_httpc_adapter.erl )

  # Inject the patched .beam files into the escript's zip archive.
  mkdir -p "$TMP/zipfs/certifi/ebin" "$TMP/zipfs/rebar/ebin"
  cp "$TMP/certifi.beam" "$TMP/zipfs/certifi/ebin/"
  cp "$TMP/rebar_httpc_adapter.beam" "$TMP/zipfs/rebar/ebin/"
  ( cd "$TMP/zipfs" && zip -q "$TMP/archive.zip" \
      certifi/ebin/certifi.beam \
      rebar/ebin/rebar_httpc_adapter.beam )

  cat "$TMP/header" "$TMP/archive.zip" > "$REBAR3.tmp"
  chmod +x "$REBAR3.tmp"
  mv "$REBAR3.tmp" "$REBAR3"
  touch "$PATCH_MARKER"
  echo "rebar3 patched."
fi

echo "Environment setup complete."

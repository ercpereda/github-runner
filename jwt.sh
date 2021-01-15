#!/bin/bash

# Shared content to use as template
header_template='{
    "typ": "JWT",
    "kid": "0001"
}'

build_header() {
        jq -c \
                --arg alg "${1:-HS256}" \
        '
        .alg = $alg
        ' <<<"$header_template" | tr -d '\n'
}

build_payload() {
        jq -c \
                --arg iat_str "$(date +%s)" \
                --arg iss "${1}" \
        '
        ($iat_str | tonumber) as $iat
        | .iss = $iss
        | .iat = $iat
        | .exp = ($iat + 600)
        ' <<<"{}" | tr -d '\n'
}

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
hs_sign() { openssl dgst -binary -sha"${1}" -hmac "$2"; }
rs_sign() { openssl dgst -binary -sha"${1}" -sign <(printf '%s\n' "$2"); }

sign() {
        local algo payload header sig secret=$3
        algo=${1:-RS256}
        header=$(build_header "$algo") || return
        payload=$(build_payload "$2") || return
        signed_content="$(json <<<"$header" | b64enc).$(json <<<"$payload" | b64enc)"
        case $algo in
                HS*) sig=$(printf %s "$signed_content" | hs_sign "${algo#HS}" "$secret" | b64enc) ;;
                RS*) sig=$(printf %s "$signed_content" | rs_sign "${algo#RS}" "$secret" | b64enc) ;;
                *) echo "Unknown algorithm" >&2; return 1 ;;
        esac
        printf '%s.%s\n' "${signed_content}" "${sig}"
}

(( $# )) && sign "$@"

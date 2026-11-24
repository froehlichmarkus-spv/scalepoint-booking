# database-url.sh — parse, encode and redact a PostgreSQL URL.
#
# Sourced by start-docker.sh. A password may contain / @ : # ? % and may be
# percent-encoded. The last "@" ends the userinfo, because a raw "@" inside
# the password is otherwise indistinguishable from the authority separator.
# Discrete DATABASE_HOST, DATABASE_PORT, POSTGRES_USER, POSTGRES_DB and
# POSTGRES_PASSWORD win when the operator set them (the *_SET flags). They
# are never overwritten by the URL.

url_decode() {
    local rest="$1" out="" hex
    while [[ "$rest" =~ ^([^%]*)%([0-9A-Fa-f][0-9A-Fa-f])(.*)$ ]]; do
        out+="${BASH_REMATCH[1]}"
        printf -v hex '%b' "\\x${BASH_REMATCH[2]}"
        out+="$hex"
        rest="${BASH_REMATCH[3]}"
    done
    printf '%s' "${out}${rest}"
}

url_encode() {
    local s="$1" i byte hex out=""
    LC_ALL=C
    for ((i = 0; i < ${#s}; i++)); do
        byte="${s:i:1}"
        case "$byte" in
            [a-zA-Z0-9.~_-]) out+="$byte" ;;
            *)
                printf -v hex '%%%02X' "'$byte"
                out+="$hex"
                ;;
        esac
    done
    printf '%s' "$out"
}

# Sets PARSED_DB_SCHEME, USER, PASSWORD, HOST, PORT, NAME, QUERY.
# Returns 1 when the URL has no host.
parse_database_url() {
    local url="$1" rest userinfo hostpart after path
    PARSED_DB_SCHEME=""
    PARSED_DB_USER=""
    PARSED_DB_PASSWORD=""
    PARSED_DB_HOST=""
    PARSED_DB_PORT=""
    PARSED_DB_NAME=""
    PARSED_DB_QUERY=""

    case "$url" in
        *://*) ;;
        *) return 1 ;;
    esac

    PARSED_DB_SCHEME="${url%%://*}"
    rest="${url#*://}"

    userinfo=""
    hostpart="$rest"
    case "$rest" in
        *@*)
            # Last "@": a password may itself contain "@".
            userinfo="${rest%@*}"
            hostpart="${rest##*@}"
            ;;
    esac
    # A fragment belongs to the host part. A "#" before the last "@" is
    # inside the password and must survive.
    hostpart="${hostpart%%#*}"

    if [ -n "$userinfo" ]; then
        case "$userinfo" in
            *:*)
                PARSED_DB_USER="$(url_decode "${userinfo%%:*}")"
                PARSED_DB_PASSWORD="$(url_decode "${userinfo#*:}")"
                ;;
            *)
                PARSED_DB_USER="$(url_decode "$userinfo")"
                ;;
        esac
    fi

    after=""
    case "$hostpart" in
        \[*)
            PARSED_DB_HOST="${hostpart#\[}"
            PARSED_DB_HOST="${PARSED_DB_HOST%%\]*}"
            after="${hostpart#*\]}"
            ;;
        *)
            after="$hostpart"
            ;;
    esac

    case "$after" in
        *\?*)
            PARSED_DB_QUERY="${after#*\?}"
            after="${after%%\?*}"
            ;;
    esac

    case "$after" in
        */*)
            path="${after#*/}"
            PARSED_DB_NAME="$(url_decode "${path%%/*}")"
            after="${after%%/*}"
            ;;
    esac

    if [ -z "$PARSED_DB_HOST" ]; then
        case "$after" in
            *:*)
                PARSED_DB_HOST="$(url_decode "${after%%:*}")"
                PARSED_DB_PORT="${after##*:}"
                ;;
            *)
                PARSED_DB_HOST="$(url_decode "$after")"
                ;;
        esac
    else
        case "$after" in
            :*)
                PARSED_DB_PORT="${after#:}"
                ;;
        esac
        PARSED_DB_HOST="$(url_decode "$PARSED_DB_HOST")"
    fi

    [ -n "$PARSED_DB_HOST" ]
}

apply_discrete_database_overrides() {
    if [ -n "${DATABASE_HOST_SET:-}" ]; then
        PARSED_DB_HOST="${DATABASE_HOST:-}"
    fi
    if [ -n "${DATABASE_PORT_SET:-}" ]; then
        PARSED_DB_PORT="${DATABASE_PORT:-}"
    fi
    if [ -n "${POSTGRES_USER_SET:-}" ]; then
        PARSED_DB_USER="${POSTGRES_USER:-}"
    fi
    if [ -n "${POSTGRES_DB_SET:-}" ]; then
        PARSED_DB_NAME="${POSTGRES_DB:-}"
    fi
    if [ -n "${POSTGRES_PASSWORD_SET:-}" ]; then
        PARSED_DB_PASSWORD="${POSTGRES_PASSWORD:-}"
    fi
}

build_database_url() {
    local auth="" host="$PARSED_DB_HOST" port="" path="" query=""
    if [ -n "$PARSED_DB_USER" ] || [ -n "$PARSED_DB_PASSWORD" ]; then
        if [ -n "$PARSED_DB_PASSWORD" ]; then
            auth="$(url_encode "$PARSED_DB_USER"):$(url_encode "$PARSED_DB_PASSWORD")@"
        else
            auth="$(url_encode "$PARSED_DB_USER")@"
        fi
    fi
    case "$host" in
        *:*) host="[$host]" ;;
    esac
    if [ -n "$PARSED_DB_PORT" ]; then
        port=":$PARSED_DB_PORT"
    fi
    if [ -n "$PARSED_DB_NAME" ]; then
        path="/$(url_encode "$PARSED_DB_NAME")"
    fi
    if [ -n "$PARSED_DB_QUERY" ]; then
        query="?$PARSED_DB_QUERY"
    fi
    printf '%s://%s%s%s%s%s' "$PARSED_DB_SCHEME" "$auth" "$host" "$port" "$path" "$query"
}

# Never prints the userinfo. A URL that cannot be parsed is replaced wholesale.
redact_database_url() {
    local url="$1" scheme rest hostpart
    case "$url" in
        *://*) ;;
        *)
            printf '%s' '<unparsed database url>'
            return 0
            ;;
    esac
    scheme="${url%%://*}"
    rest="${url#*://}"
    case "$rest" in
        *@*)
            hostpart="${rest##*@}"
            printf '%s://***:***@%s' "$scheme" "$hostpart"
            ;;
        *)
            printf '%s' "$url"
            ;;
    esac
}

#!/usr/bin/env bash
#
# recon.sh — Simple recon pipeline: subfinder -> httpx -> naabu -> katana
#
# Usage:
#   ./recon.sh example.com
#   ./recon.sh -o /path/to/output example.com
#
# Requires: subfinder, httpx, naabu, katana (all from ProjectDiscovery)
#

set -euo pipefail

# ----------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------
OUTDIR_BASE="./recon"
THREADS=50

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [options] <domain>

Options:
  -o <dir>    Base output directory (default: ./recon)
  -t <num>    Threads/concurrency for httpx & naabu (default: 50)
  -h          Show this help

Example:
  $0 example.com
  $0 -o /tmp/scans -t 100 example.com
EOF
    exit 1
}

log() {
    # Timestamped status line to stderr so it doesn't pollute piped output
    echo -e "\n\033[1;34m[*] $(date '+%H:%M:%S') $*\033[0m" >&2
}

err() {
    echo -e "\033[1;31m[!] $*\033[0m" >&2
}

check_deps() {
    local missing=0
    for tool in subfinder httpx naabu katana; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "Missing required tool: $tool"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        err "Install missing tools with: go install github.com/projectdiscovery/<tool>/..."
        exit 1
    fi
}

# ----------------------------------------------------------------------
# Parse arguments
# ----------------------------------------------------------------------
while getopts ":o:t:h" opt; do
    case "$opt" in
        o) OUTDIR_BASE="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        h) usage ;;
        \?) err "Unknown option: -$OPTARG"; usage ;;
        :)  err "Option -$OPTARG requires an argument"; usage ;;
    esac
done
shift $((OPTIND - 1))

DOMAIN="${1:-}"
[ -z "$DOMAIN" ] && usage

check_deps

# ----------------------------------------------------------------------
# Set up output directory
# ----------------------------------------------------------------------
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
OUTDIR="${OUTDIR_BASE}/${DOMAIN}_${TIMESTAMP}"
mkdir -p "$OUTDIR"

SUBS="$OUTDIR/subdomains.txt"
LIVE="$OUTDIR/live.txt"
PORTS="$OUTDIR/ports.txt"
URLS="$OUTDIR/urls.txt"

log "Target: $DOMAIN"
log "Output: $OUTDIR"

# ----------------------------------------------------------------------
# Stage 1: Subdomain enumeration (subfinder)
# ----------------------------------------------------------------------
log "Stage 1/4 — Enumerating subdomains with subfinder"
subfinder -d "$DOMAIN" -all -silent -o "$SUBS" || true

if [ ! -s "$SUBS" ]; then
    err "No subdomains found. Exiting."
    exit 1
fi
log "Found $(wc -l < "$SUBS" | tr -d ' ') subdomains -> $SUBS"

# ----------------------------------------------------------------------
# Stage 2: Probe for live hosts (httpx)
# ----------------------------------------------------------------------
log "Stage 2/4 — Probing for live hosts with httpx"
httpx -l "$SUBS" -silent -threads "$THREADS" -o "$LIVE" || true

if [ ! -s "$LIVE" ]; then
    err "No live hosts found. Exiting."
    exit 1
fi
log "Found $(wc -l < "$LIVE" | tr -d ' ') live hosts -> $LIVE"

# httpx outputs URLs like https://host — strip scheme for naabu, which wants hosts
LIVE_HOSTS="$OUTDIR/live_hosts.txt"
sed -E 's~^https?://~~; s~/.*$~~; s~:.*$~~' "$LIVE" | sort -u > "$LIVE_HOSTS"

# ----------------------------------------------------------------------
# Stage 3: Port scan (naabu)
# ----------------------------------------------------------------------
log "Stage 3/4 — Scanning ports with naabu"
naabu -l "$LIVE_HOSTS" -silent -c "$THREADS" -o "$PORTS" || true

if [ -s "$PORTS" ]; then
    log "Open ports written to $PORTS ($(wc -l < "$PORTS" | tr -d ' ') host:port pairs)"
else
    err "No open ports found (or naabu needs elevated privileges for SYN scan)."
fi

# ----------------------------------------------------------------------
# Stage 4: Crawl URLs (katan)a
# ----------------------------------------------------------------------
log "Stage 4/4 — Crawling URLs with katana"
# Feed katana the live URLs (with scheme) that httpx already confirmed
katana -list "$LIVE" -silent -d 3 -jc -o "$URLS" || true

if [ -s "$URLS" ]; then
    log "Crawled $(wc -l < "$URLS" | tr -d ' ') URLs -> $URLS"
else
    err "No URLs crawled."
fi

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
log "Done. Summary:"
{
    echo "Domain:      $DOMAIN"
    echo "Subdomains:  $([ -s "$SUBS" ]  && wc -l < "$SUBS"  | tr -d ' ' || echo 0)"
    echo "Live hosts:  $([ -s "$LIVE" ]  && wc -l < "$LIVE"  | tr -d ' ' || echo 0)"
    echo "Open ports:  $([ -s "$PORTS" ] && wc -l < "$PORTS" | tr -d ' ' || echo 0)"
    echo "URLs:        $([ -s "$URLS" ]  && wc -l < "$URLS"  | tr -d ' ' || echo 0)"
    echo "Output dir:  $OUTDIR"
} | tee "$OUTDIR/summary.txt" >&2
#!/usr/bin/env sh
# nmapAutomator v2.0.0
# Author: @H4N1K
# Hardened & Safe Edition

set -o errexit
set -o pipefail
set -o nounset

########################################
# Colors
########################################
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

########################################
# Defaults
########################################
REMOTE=false
SAFE_MODE=false
OUTPUTDIR=""
DNSSTRING="--system-dns"
NMAP_RATE="${NMAP_RATE:-300}"

elapsedStart="$(date +%s)"

########################################
# Usage
########################################
usage() {
  printf "${RED}Usage:${NC} %s -H <host> -t <type> [options]\n\n" "$(basename "$0")"
  printf "Scan Types:\n"
  printf "  Network | Port | Script | Full | UDP | Vulns | Recon | All\n\n"
  printf "Options:\n"
  printf "  -r, --remote          Remote mode (no local nmap)\n"
  printf "  --safe                Safe mode (no eval execution)\n"
  printf "  -d, --dns <server>    Custom DNS server\n"
  printf "  -o, --output <dir>    Output directory\n"
  printf "  -s, --static-nmap     Static nmap binary\n\n"
  exit 1
}

########################################
# Argument Parsing
########################################
while [ $# -gt 0 ]; do
  case "$1" in
    -H|--host) HOST="$2"; shift 2 ;;
    -t|--type) TYPE="$2"; shift 2 ;;
    -r|--remote) REMOTE=true; shift ;;
    --safe) SAFE_MODE=true; shift ;;
    -d|--dns) DNSSTRING="--dns-server=$2"; shift 2 ;;
    -o|--output) OUTPUTDIR="$2"; shift 2 ;;
    -s|--static-nmap) NMAPPATH="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ -z "${HOST:-}" ] || [ -z "${TYPE:-}" ] && usage

########################################
# Validate TYPE
########################################
case "${TYPE}" in
  Network|network|Port|port|Script|script|Full|full|UDP|udp|Vulns|vulns|Recon|recon|All|all)
    ;;
  *)
    printf "${RED}Invalid scan type!${NC}\n"
    usage
    ;;
esac

########################################
# Prepare Environment
########################################
OUTPUTDIR="${OUTPUTDIR:-$HOST}"
mkdir -p "$OUTPUTDIR"/{nmap,recon}
cd "$OUTPUTDIR"

########################################
# Nmap Binary
########################################
if ! $REMOTE; then
  if [ -n "${NMAPPATH:-}" ]; then
    chmod +x "$NMAPPATH" || REMOTE=true
  elif command -v nmap >/dev/null 2>&1; then
    NMAPPATH="$(command -v nmap)"
  else
    printf "${YELLOW}Nmap not found. Switching to Remote mode.${NC}\n"
    REMOTE=true
  fi
fi

########################################
# Safe Command Runner
########################################
run_cmd() {
  if $SAFE_MODE; then
    printf "${YELLOW}[SAFE] %s${NC}\n" "$*"
  else
    sh -c "$*"
  fi
}

########################################
# Header
########################################
header() {
  printf "${GREEN}=========================================${NC}\n"
  printf "${GREEN} nmapAutomator v2.0.0${NC}\n"
  printf "${GREEN} Target: %s | Mode: %s${NC}\n" "$HOST" "$( $REMOTE && echo REMOTE || echo LOCAL )"
  printf "${GREEN}=========================================${NC}\n\n"
}

########################################
# Scans
########################################
portScan() {
  printf "${GREEN}[*] Port Scan${NC}\n"
  $REMOTE && { printf "${YELLOW}Remote mode: skipped${NC}\n"; return; }
  run_cmd "$NMAPPATH -T4 --open -oN nmap/Port_${HOST}.nmap $HOST $DNSSTRING"
}

scriptScan() {
  printf "${GREEN}[*] Script Scan${NC}\n"
  $REMOTE && return
  ports="$(awk -F/ '/^[0-9]/{print $1}' nmap/Port_${HOST}.nmap | paste -sd,)"
  [ -z "$ports" ] && return
  run_cmd "$NMAPPATH -sCV -p$ports -oN nmap/Script_${HOST}.nmap $HOST $DNSSTRING"
}

fullScan() {
  printf "${GREEN}[*] Full Scan${NC}\n"
  $REMOTE && return
  run_cmd "$NMAPPATH -p- --max-rate $NMAP_RATE -T4 -oN nmap/Full_${HOST}.nmap $HOST $DNSSTRING"
}

vulnsScan() {
  printf "${GREEN}[*] Vulns Scan${NC}\n"
  $REMOTE && return
  run_cmd "$NMAPPATH -sV --script vuln -oN nmap/Vulns_${HOST}.nmap $HOST"
}

reconScan() {
  printf "${GREEN}[*] Recon Recommendations${NC}\n"
  printf "Check nmap results and run tools manually or via scripts.\n"
}

########################################
# Main
########################################
main() {
  header
  case "$TYPE" in
    Network|network) printf "Network scan placeholder\n" ;;
    Port|port) portScan ;;
    Script|script) portScan; scriptScan ;;
    Full|full) fullScan ;;
    UDP|udp) printf "UDP scan placeholder\n" ;;
    Vulns|vulns) portScan; vulnsScan ;;
    Recon|recon) reconScan ;;
    All|all)
      portScan
      scriptScan
      fullScan
      vulnsScan
      reconScan
      ;;
  esac
}

main

########################################
# Footer
########################################
elapsedEnd="$(date +%s)"
printf "\n${GREEN}Completed in %s seconds${NC}\n" "$((elapsedEnd - elapsedStart))"

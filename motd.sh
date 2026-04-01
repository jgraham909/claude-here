#!/bin/bash
# Claude Code Sandbox — startup screen
# Sourced from .zshrc / .bashrc on shell open.

# ── ANSI codes ────────────────────────────────────────────────────────────────
RST='\033[0m'
B='\033[1m'
DIM='\033[2m'
GRN='\033[32m'
RED='\033[31m'
YLW='\033[33m'
CYN='\033[36m'

# ── Box geometry ──────────────────────────────────────────────────────────────
TW=60          # total width including border chars
IW=$((TW - 4)) # inner content width (between "║ " and " ║")

# Visible string length — strips ANSI escape codes before measuring
vlen() {
	python3 -c "
import re, sys
s = sys.stdin.read().rstrip('\n')
print(len(re.sub(r'\x1b\[[0-9;]*m', '', s)))
" <<<"$1"
}

# Print a content row inside the box
row() {
	local s="$1"
	local vl pad
	vl=$(vlen "$s")
	pad=$((IW - vl))
	[ "$pad" -lt 0 ] && pad=0
	printf '║ '
	printf '%s' "$s"
	printf "%${pad}s ║\n" ""
}

# Print a horizontal divider
div() {
	local l="${1:-╠}" r="${2:-╣}"
	printf '%s' "$l"
	python3 -c "print('═' * $((TW - 2)), end='')"
	printf '%s\n' "$r"
}

# ── Status icons ──────────────────────────────────────────────────────────────
CHK=$(printf '%b' "${GRN}✓${RST}")
CRS=$(printf '%b' "${RED}✗${RST}")
CLK=$(printf '%b' "${YLW}⏱${RST}")

# ── Installed versions (local, fast) ─────────────────────────────────────────
CLAUDE_INST=$(npm list -g @anthropic-ai/claude-code --depth=0 2>/dev/null |
	grep claude-code | awk -F'@' '{print $NF}' | tr -d ' \n')
ANTHR_INST=$(python3 -c "import anthropic; print(anthropic.__version__)" 2>/dev/null ||
	echo "n/a")
CODEX_INST=$(npm list -g @openai/codex --depth=0 2>/dev/null |
	grep '@openai/codex' | awk -F'@' '{print $NF}' | tr -d ' \n')
NODE_V=$(node -e "process.stdout.write(process.version.slice(1))" 2>/dev/null ||
	echo "n/a")
PY_V=$(python3 -c "import sys; v=sys.version_info; print(f'{v.major}.{v.minor}.{v.micro}')" \
	2>/dev/null || echo "n/a")
GIT_V=$(git --version 2>/dev/null | awk '{print $3}' || echo "n/a")
GH_V=$(gh --version 2>/dev/null | awk 'NR==1{print $3}' || echo "n/a")

# ── Remote checks — parallel, 3s timeout each ────────────────────────────────
T1=$(mktemp)
T2=$(mktemp)
T3=$(mktemp)
T4=$(mktemp)

(timeout 3 npm view @anthropic-ai/claude-code version 2>/dev/null >"$T1") &
PID1=$!

(timeout 3 curl -sf https://pypi.org/pypi/anthropic/json 2>/dev/null |
	python3 -c "import sys,json; print(json.load(sys.stdin)['info']['version'])" \
		2>/dev/null >"$T2") &
PID2=$!

(if [ -n "$HTTP_PROXY" ]; then
	PHOST="${HTTP_PROXY#*//}"
	PHOST="${PHOST%%:*}"
	PPORT="${HTTP_PROXY##*:}"
	timeout 3 bash -c "echo >/dev/tcp/${PHOST}/${PPORT}" 2>/dev/null && echo ok >"$T3"
fi) &
PID3=$!

(timeout 3 npm view @openai/codex version 2>/dev/null >"$T4") &
PID4=$!

wait $PID1 $PID2 $PID3 $PID4 2>/dev/null

CLAUDE_LATEST=$(tr -d ' \n' <"$T1")
rm -f "$T1"
ANTHR_LATEST=$(tr -d ' \n' <"$T2")
rm -f "$T2"
PROXY_STATUS=$(cat "$T3")
rm -f "$T3"
CODEX_LATEST=$(tr -d ' \n' <"$T4")
rm -f "$T4"

# ── Format a version check row ────────────────────────────────────────────────
ver_row() {
	local label="$1" inst="$2" latest="$3"
	local status
	if [ -z "$latest" ]; then
		status="${CLK} timed out"
	elif [ "$inst" = "$latest" ]; then
		status="${CHK} up to date"
	else
		status="${CRS} $(printf "${YLW}%s available${RST}" "$latest")"
	fi
	printf "${B}%-14s${RST}${CYN}%-12s${RST}%s" "$label" "$inst" "$status"
}

# ── Proxy row ─────────────────────────────────────────────────────────────────
PROXY_ROW2=""
if [ "${UNFILTERED:-}" = "1" ]; then
	PROXY_ROW=$(printf '%b' "${B}network${RST}         ${YLW}⚠  unfiltered — direct internet access${RST}")
elif [ "$PROXY_STATUS" = "ok" ]; then
	PROXY_ROW=$(printf '%b' "${B}filtering proxy${RST} ${CHK} active — domain allowlist enforced")
	PROXY_ROW2=$(printf "${DIM}via ai_filtering_proxy · %s${RST}" "${HTTP_PROXY:-unknown}")
else
	PROXY_ROW=$(printf '%b' "${B}filtering proxy${RST} ${CRS} ${RED}UNREACHABLE — network may be broken${RST}")
	PROXY_ROW2=$(printf "${DIM}via ai_filtering_proxy · %s${RST}" "${HTTP_PROXY:-unknown}")
fi

# ── Render ────────────────────────────────────────────────────────────────────

echo
div "╔" "╗"
row "$(printf '%b' "  ${B}${CYN}AI Harness Sandbox${RST}")"
row "$(printf '%b' "  ${DIM}Built: ${BUILD_DATE:-unknown}${RST}")"
div
row "$(printf "${DIM}node${RST} %-8s  ${DIM}python${RST} %-7s  ${DIM}git${RST} %-8s  ${DIM}gh${RST} %s" \
	"$NODE_V" "$PY_V" "$GIT_V" "$GH_V")"
div
row "$(ver_row "claude-code" "$CLAUDE_INST" "$CLAUDE_LATEST")"
row "$(ver_row "anthropic" "$ANTHR_INST" "$ANTHR_LATEST")"
row "$(ver_row "codex" "$CODEX_INST" "$CODEX_LATEST")"
div
row "$PROXY_ROW"
[ -n "$PROXY_ROW2" ] && row "$PROXY_ROW2"
div "╚" "╝"
echo

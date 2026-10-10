#!/bin/bash
# credit goes to crossystem for finding the script, naggets and ap5z for leaking it
set -e
BANNER=/etc/issue

get_board() {
    local b
    b="$(crossystem hwid 2>/dev/null | awk '{print tolower($1)}')"
    [ -z "$b" ] && b="$(grep CHROMEOS_RELEASE_BOARD /etc/lsb-release 2>/dev/null | cut -d= -f2)"
    echo "${b:-unknown}"
}

get_kernver() {
    local raw
    raw="$(crossystem tpm_kernver 2>/dev/null)"
    [ -z "$raw" ] && echo "unknown" && return
    printf "%d" "$((raw & 0xff))" 2>/dev/null || echo "unknown"
}

get_milestone() {
    grep CHROMEOS_RELEASE_MILESTONE /etc/lsb-release 2>/dev/null | cut -d= -f2
}

while true; do
    clear
    cat "$BANNER" 2>/dev/null || echo "  FLOGWRITE"
    echo ""
    KV="$(get_kernver)"
    MILE="$(get_milestone)"
    BOARD="$(get_board)"
    echo "  board: $BOARD   cros: M$MILE   kernver: $KV"
    echo ""
    echo "  1) flogwrite.sh"
    echo "  2) Reboot"
    echo "  3) Shell"
    echo ""
    read -p "  Choose option: " choice

    case "$(echo "$choice" | tr 'a-z' 'A-Z')" in
        1) /usr/share/cros/flogwrite.sh 2>&1 | tee /tmp/flogwrite_out.txt; read -p "  Press Enter to continue..." ;;
        2) reboot -f ;;
        3) echo "  Type 'exit' to return"; bash ;;
        *) echo "  Invalid."; sleep 1 ;;
    esac
done

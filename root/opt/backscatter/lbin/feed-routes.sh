#!/bin/sh
#
# Copyright © (2006-2023) Fredrik Söderblom <fredrik@xpd.se>
#
# This file is part of Backscatter.
#
# Backscatter is free software: you can redistribute it and/or modify it under the terms of the
# GNU Affero General Public License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# Backscatter is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#  See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License along with
# Backscatter. If not, see <https://www.gnu.org/licenses/>.
#
# feed-routes.sh: feed routes to backscatter AnyIP listener
#
# When       Who                What
# 2020-04-20 fredrik@xpd.se     created.
# 2026-08-06 fredrik@xpd.se     added start, status and stop.

set -u
set -f

PATH=/usr/sbin:/usr/bin:/sbin:/bin
LC_ALL=C
export PATH LC_ALL

PROG=${0##*/}
LOG_FACILITY=daemon

CIDR_RANGES=/opt/backscatter/etc/cidr-ranges.conf
TPROXY_IP=127.0.0.1
TPROXY_PORT=1234

IP=/usr/sbin/ip
IPTABLES=/usr/sbin/iptables

#
# Functions
#

info()
{
        MSG="INFO: $1"
        logger -t "$PROG" -p "$LOG_FACILITY.info" "$MSG"
        printf '%s\n' "$MSG"
}

notice()
{
        MSG="NOTICE: $1"
        logger -t "$PROG" -p "$LOG_FACILITY.notice" "$MSG"
        printf '%s\n' "$MSG"
}

warning()
{
        MSG="WARNING: $1"
        logger -t "$PROG" -p "$LOG_FACILITY.warning" "$MSG"
        printf '%s\n' "$MSG" >&2
}

fatal()
{
        MSG="FATAL: $1 (bailing out)"
        logger -t "$PROG" -p "$LOG_FACILITY.err" "$MSG"
        printf '%s\n' "$MSG" >&2
        exit 1
}

usage()
{
        printf 'Usage: %s {start|status|stop}\n' "$PROG" >&2
        exit 2
}

valid_ipv4_cidr()
{
        awk -v cidr="$1" 'BEGIN {
                if (split(cidr, part, "/") != 2 ||
                    part[2] !~ /^[0-9]+$/ ||
                    part[2] < 0 || part[2] > 32 ||
                    split(part[1], octet, ".") != 4) {
                        exit 1
                }

                for (i = 1; i <= 4; i++) {
                        if (octet[i] !~ /^[0-9]+$/ ||
                            octet[i] < 0 || octet[i] > 255) {
                                exit 1
                        }
                }

                exit 0
        }'
}

route_present()
{
        "$IP" -o -4 route show table local 2>/dev/null |
                awk -v net="$1" '
                        $1 == "local" {
                                prefix = $2

                                # iproute2 may display a host route
                                # without an explicit /32.
                                if (prefix !~ /\//) {
                                        prefix = prefix "/32"
                                }

                                if (prefix == net) {
                                        for (i = 1; i <= NF; i++) {
                                                if ($i == "dev" &&
                                                    $(i + 1) == "lo") {
                                                        found = 1
                                                }
                                        }
                                }
                        }

                        END {
                                exit(found ? 0 : 1)
                        }
                '
}

iptables_rule_present()
{
        "$IPTABLES" -t mangle -C PREROUTING \
                -d "$1" \
                -p tcp \
                -j TPROXY \
                --on-port "$TPROXY_PORT" \
                --on-ip "$TPROXY_IP" \
                >/dev/null 2>&1
}

start_range()
{
        NET=$1

        if route_present "$NET"; then
                notice "$NET: local route already present."
        else
                "$IP" -4 route add table local local "$NET" \
                        dev lo src "$TPROXY_IP" ||
                        fatal "$NET: failed to add local route."

                info "$NET: local route added."
        fi

        if iptables_rule_present "$NET"; then
                notice "$NET: mangle PREROUTING rule already present."
        else
                "$IPTABLES" -t mangle -I PREROUTING \
                        -d "$NET" \
                        -p tcp \
                        -j TPROXY \
                        --on-port "$TPROXY_PORT" \
                        --on-ip "$TPROXY_IP" ||
                        fatal "$NET: failed to add mangle PREROUTING rule."

                info "$NET: mangle PREROUTING rule added."
        fi
}

stop_range()
{
        NET=$1
        RULE_REMOVED=0

        # Remove all matching rules in case an older run
        # accidentally created duplicates.
        while iptables_rule_present "$NET"; do
                "$IPTABLES" -t mangle -D PREROUTING \
                        -d "$NET" \
                        -p tcp \
                        -j TPROXY \
                        --on-port "$TPROXY_PORT" \
                        --on-ip "$TPROXY_IP" ||
                        fatal "$NET: failed to remove mangle PREROUTING rule."

                RULE_REMOVED=1
        done

        if [ "$RULE_REMOVED" -eq 1 ]; then
                info "$NET: mangle PREROUTING rule removed."
        else
                notice "$NET: no mangle PREROUTING rule present."
        fi

        if route_present "$NET"; then
                "$IP" -4 route del table local local "$NET" dev lo src "$TPROXY_IP" ||
                        fatal "$NET: failed to remove local route."

                info "$NET: local route removed."
        else
                notice "$NET: no local route present."
        fi
}

status_range()
{
        NET=$1
        ROUTE_STATUS=missing
        RULE_STATUS=missing

        if route_present "$NET"; then
                ROUTE_STATUS=present
        else
                STATUS_RC=3
        fi

        if iptables_rule_present "$NET"; then
                RULE_STATUS=present
        else
                STATUS_RC=3
        fi

        printf '%-18s route: %-7s  tproxy: %s\n' \
                "$NET" "$ROUTE_STATUS" "$RULE_STATUS"
}

#
# Main
#

[ "$#" -eq 1 ] || usage
ACTION=$1

case "$ACTION" in
        start|status|stop)
                ;;
        *)
                usage
                ;;
esac

[ "$(id -u)" -eq 0 ] ||
        fatal "Must be run as root."

[ -r "$CIDR_RANGES" ] ||
        fatal "Cannot read $CIDR_RANGES."

[ -x "$IP" ] ||
        fatal "$IP is not executable."

[ -x "$IPTABLES" ] ||
        fatal "$IPTABLES is not executable."

STATUS_RC=0
RANGE_COUNT=0
LINE_NUMBER=0

while IFS= read -r LINE || [ -n "$LINE" ]; do
        LINE_NUMBER=$((LINE_NUMBER + 1))

        # Remove full-line and trailing comments.
        LINE=${LINE%%#*}

        # Use the first whitespace-separated field as the CIDR range.
        set -- $LINE
        [ "$#" -gt 0 ] || continue

        NET=$1

        if ! valid_ipv4_cidr "$NET"; then
                warning \
                        "$CIDR_RANGES:$LINE_NUMBER: invalid IPv4 CIDR: $NET"

                STATUS_RC=2
                continue
        fi

        RANGE_COUNT=$((RANGE_COUNT + 1))

        case "$ACTION" in
                start)
                        start_range "$NET"
                        ;;
                status)
                        status_range "$NET"
                        ;;
                stop)
                        stop_range "$NET"
                        ;;
        esac
done < "$CIDR_RANGES"

[ "$RANGE_COUNT" -gt 0 ] ||
        fatal "No valid CIDR ranges found in $CIDR_RANGES."

exit "$STATUS_RC"

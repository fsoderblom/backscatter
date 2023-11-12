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
# feed-routes.sh: feed routes to backscatters anyip listener
#
# When       Who		What
# 2020-04-20 fredrik@xpd.se	created.

PATH=/usr/sbin:/usr/bin:/sbin:/bin
PROG=$(basename $0)
LOG_FACILITY="daemon"

CIDR_RANGES="/opt/backscatter/etc/cidr-ranges.conf"

# ip route show table local
# ip route get to 2.0.0.0
# local 2.0.0.0 dev lo src 127.0.0.1
#    cache <local>
# iptables -t mangle -nvL PREROUTING

#
# start of functions
#

info() # msg
{
	MSG="INFO: $1"
	logger -t $PROG -p $LOG_FACILITY.info "$MSG"
	echo "$MSG"
}

notice() # msg
{
	MSG="NOTICE: $1"
	logger -t $PROG -p $LOG_FACILITY.warn "$MSG"
	echo "$MSG"
}

fatal() # msg
{
	MSG="FATAL: $1 (bailing out)"
	logger -t $PROG -p $LOG_FACILITY.error "$MSG"
	echo "$MSG"
	exit 255
}

#
# end of functions - start of main
#

if [ ! -f $CIDR_RANGES ]; then
	fatal "ERROR: "
	exit 1
fi

for NET in $(grep -vE "^#" $CIDR_RANGES | awk ' { print $1 } ')
do
	if [ $(/usr/sbin/ip route get to $NET | grep -c "dev lo") -lt 1 ]; then
		/usr/sbin/ip route add local $NET dev lo src 127.0.0.1
		info "$NET: local route added."
	else
		notice "Local route for $NET already inserted."
	fi

	if [ $(/usr/sbin/iptables -t mangle -nL PREROUTING | grep -c " $NET ") -lt 1 ]; then
		/usr/sbin/iptables -t mangle -I PREROUTING -d $NET -p tcp -j TPROXY --on-port=1234 --on-ip=127.0.0.1
		info "$NET: mangle prerouting entry added."
	else
		notice "Mangle prerouting rule for $NET already inserted."
	fi
done
exit 0

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

## Grants for backscatter@localhost ##
## Used by both the backscatter daemon (INSERT into matches, REPLACE into
## state) and purge_backscatter.pl (SELECT/DELETE for trimming). REPLACE is
## internally DELETE+INSERT, so no UPDATE privilege is needed. Schema changes
## are never performed at runtime, so ALL PRIVILEGES is intentionally avoided.
CREATE USER 'backscatter'@'localhost' IDENTIFIED BY 'another-super-sikrit-password-long-and-complicated';
GRANT SELECT, INSERT, DELETE ON `backscatter`.`matches` TO 'backscatter'@'localhost';
GRANT SELECT, INSERT, DELETE ON `backscatter`.`state` TO 'backscatter'@'localhost';
GRANT SELECT ON `backscatter`.`whitelist_rules` TO 'backscatter'@'localhost';
GRANT SELECT ON `backscatter`.`whitelist_cidrs` TO 'backscatter'@'localhost';
GRANT SELECT ON `backscatter`.`whitelist_port_predicates` TO 'backscatter'@'localhost';

## Grants for bracksmatter@localhost ##
CREATE USER 'bracksmatter'@'localhost' IDENTIFIED BY 'super-sikrit-password-long-and-complicated';
GRANT SELECT ON `backscatter`.* TO 'bracksmatter'@'localhost';

## Grants for whitelist@localhost ##
## Used by whitelist_ctl.pl to manage whitelist entries. Kept separate from
## backscatter@localhost so the daemon itself never has write access to its
## own filtering rules -- only an operator running the CLI tool does.
CREATE USER 'whitelist'@'localhost' IDENTIFIED BY 'yet-another-super-sikrit-password-long-and-complicated';
GRANT SELECT, INSERT, UPDATE, DELETE ON `backscatter`.`whitelist_rules` TO 'whitelist'@'localhost';
GRANT SELECT, INSERT, DELETE ON `backscatter`.`whitelist_cidrs` TO 'whitelist'@'localhost';
GRANT SELECT, INSERT, DELETE ON `backscatter`.`whitelist_port_predicates` TO 'whitelist'@'localhost';

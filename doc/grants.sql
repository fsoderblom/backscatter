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
GRANT USAGE ON *.* TO 'backscatter'@'localhost' IDENTIFIED BY 'another-super-sikrit-password-long-and-complicated';
GRANT ALL PRIVILEGES ON `backscatter`.* TO 'backscatter'@'localhost';

## Grants for bracksmatter@localhost ##
GRANT USAGE ON *.* TO 'bracksmatter'@'localhost' IDENTIFIED BY 'super-sikrit-password-long-and-complicated';
GRANT SELECT ON `backscatter`.* TO 'bracksmatter'@'localhost';

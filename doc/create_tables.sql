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

CREATE TABLE state (
  srcip varchar(100) NOT NULL DEFAULT '',
  dstip varchar(100) NOT NULL DEFAULT '',
  hits int(20) DEFAULT NULL,
  comment varchar(255) DEFAULT NULL,
  timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (srcip,dstip)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci;

CREATE TABLE matches (
  id int(11) NOT NULL AUTO_INCREMENT,
  proto varchar(20) DEFAULT NULL,
  srcip varchar(100) DEFAULT NULL,
  srcport varchar(10) DEFAULT NULL,
  dstip varchar(100) DEFAULT NULL,
  dstport varchar(10) DEFAULT NULL,
  reason varchar(255) DEFAULT NULL,
  timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY srcip (srcip,dstip),
  KEY dstport (dstport),
  KEY reason (reason)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_swedish_ci;

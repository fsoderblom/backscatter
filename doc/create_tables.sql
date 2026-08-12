# Copyright © (2006-2026) Fredrik Söderblom <fredrik@xpd.se>
#
# This file is part of Backscatter.
#
# Backscatter is free software: you can redistribute it and/or modify it under the terms of the
# GNU Affero General Public License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# Backscatter is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License along with
# Backscatter. If not, see <https://www.gnu.org/licenses/>.

CREATE TABLE state (
    srcip       VARCHAR(45) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dstip       VARCHAR(45) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    hits        INT UNSIGNED DEFAULT NULL,
    comment     VARCHAR(255) DEFAULT NULL,
    last_seen   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (srcip, dstip)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE matches (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    proto       VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
    srcip       VARCHAR(45) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
    srcport     SMALLINT UNSIGNED DEFAULT NULL,
    dstip       VARCHAR(45) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
    dstport     SMALLINT UNSIGNED DEFAULT NULL,
    reason      VARCHAR(255) DEFAULT NULL,
    timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    KEY ix_matches_src_dst (srcip, dstip),
    KEY ix_matches_dstport (dstport),
    KEY ix_matches_reason (reason)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE whitelist_rules (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    priority    SMALLINT UNSIGNED NOT NULL,
    reason      VARCHAR(255) NOT NULL,
    action      ENUM('whitelist','drop_event') NOT NULL DEFAULT 'whitelist',
    proto       VARCHAR(10) NULL,
    enabled     TINYINT(1) NOT NULL DEFAULT 1,
    comment     VARCHAR(500) NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_whitelist_priority (priority),
    KEY ix_whitelist_enabled_priority (enabled, priority, id),
    CONSTRAINT chk_whitelist_proto
      CHECK (proto IS NULL OR proto IN ('TCP','UDP','ICMP','ESP','AH'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE whitelist_cidrs (
    rule_id     INT UNSIGNED NOT NULL,
    direction   ENUM('src','dst') NOT NULL,
    cidr        VARCHAR(43) NOT NULL,
    PRIMARY KEY (rule_id, direction, cidr),
    CONSTRAINT fk_whitelist_cidr_rule FOREIGN KEY (rule_id)
      REFERENCES whitelist_rules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=ascii;

CREATE TABLE whitelist_port_predicates (
    rule_id       INT UNSIGNED NOT NULL,
    direction     ENUM('src','dst') NOT NULL,
    comparison    ENUM('numeric','lexical') NOT NULL DEFAULT 'numeric',
    operator      ENUM('eq','gt','ge','lt','le') NOT NULL,
    operand       VARCHAR(5) NOT NULL,
    PRIMARY KEY (rule_id, direction, comparison, operator, operand),
    CONSTRAINT fk_whitelist_port_rule FOREIGN KEY (rule_id)
      REFERENCES whitelist_rules(id) ON DELETE CASCADE,
    CONSTRAINT chk_whitelist_port_operand
      CHECK (CAST(operand AS UNSIGNED) BETWEEN 0 AND 65535)
) ENGINE=InnoDB DEFAULT CHARSET=ascii;

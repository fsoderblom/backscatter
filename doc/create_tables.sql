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

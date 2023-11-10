## Grants for backscatter@localhost ##
GRANT USAGE ON *.* TO 'backscatter'@'localhost' IDENTIFIED BY 'another-super-sikrit-password-long-and-complicated';
GRANT ALL PRIVILEGES ON `backscatter`.* TO 'backscatter'@'localhost';

## Grants for bracksmatter@localhost ##
GRANT USAGE ON *.* TO 'bracksmatter'@'localhost' IDENTIFIED BY 'super-sikrit-password-long-and-complicated';
GRANT SELECT ON `backscatter`.* TO 'bracksmatter'@'localhost';

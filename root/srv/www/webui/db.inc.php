<?php
$_db = parse_ini_file('/etc/backscatter/db.ini');
$db_host     = $_db['host'];
$db_user     = $_db['user'];
$db_password = $_db['password'];
$db          = $_db['database'];
unset($_db);

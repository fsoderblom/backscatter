<?php
//
// When          Who			What
// 2009-08-18    fredrik@xpd.se		created.
//

$ip = $_POST['ip'] != '' ? $_POST['ip'] : $_GET['ip'];

function gethost($ip)
{
  // Make sure the input is not going to do anything unexpected
  // IPs must be in the form x.x.x.x with each x as a number
  $testar = explode('.', $ip);
  if (count($testar) != 4)
    return $ip;
  for ($i = 0; $i < 4; ++$i)
    if (!is_numeric($testar[$i]))
      return $ip;


  $host = `host $ip`;
  return (($host ? end(explode(' ', $host)) : $ip));
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <?php include('./head.inc.php'); ?>
</head>

<body>
  <?php
  if (preg_match("/^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168)\.*/", $ip)) {
    $srchost = gethost($ip);
    if (preg_match("/.*NXDOMAIN.*/", $srchost)) {
      $srchost = "not known in DNS";
    }
  } else {
    $srchost = $ip;
  }
  ?>
  <br>
  <?php echo "$ip is $srchost"; ?>
</body>

</html>
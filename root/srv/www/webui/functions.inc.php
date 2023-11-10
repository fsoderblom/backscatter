<?php
//
// When          Who			What
// 2009-08-18    fredrik@xpd.se		created.
//

function secure_tmpname($postfix = '.tmp', $prefix = 'tmp', $dir = null)
{
  // validate arguments
  if (!(isset($postfix) && is_string($postfix))) {
    return false;
  }
  if (!(isset($prefix) && is_string($prefix))) {
    return false;
  }
  if (!isset($dir)) {
    $dir = getcwd();
  }

  // find a temporary name
  $tries = 1;
  do {
    // get a known, unique temporary file name
    $sysFileName = tempnam($dir, $prefix);
    if ($sysFileName === false) {
      return false;
    }

    // tack on the extension
    $newFileName = $sysFileName . $postfix;
    if ($sysFileName == $newFileName) {
      return $sysFileName;
    }
    // move or point the created temporary file to the new filename
    // NOTE: these fail if the new file name exist
    $newFileCreated = @link($sysFileName, $newFileName);
    if ($newFileCreated) {
      unlink($sysFileName);
      return $newFileName;
    }

    unlink($sysFileName);
    $tries++;
  } while ($tries <= 5);

  return false;
}

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

function is_wildcard($str)
{
  $pos = strpos($str, '%');
  if ($pos === false) {
    return 0;
  } else {
    return 1;
  }
}

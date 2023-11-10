<?php
//
// When         Who             What
// 2009-08-18   fredrik@xpd.se  created.
// 2020-09-12   oscar@xpd.se    refactored.

function get_argument($key, $default='')
{
  if (isset($_POST[$key]) && !empty($_POST[$key])) {
    return $_POST[$key];
  } else if (isset($_GET[$key])) {
    return $_GET[$key];
  }
  return $default;
}

$action = get_argument('Action');

if ($action == "Reset") {
  $srcip = $srcport = $dstip = $dstport = "";
} else {
  $srcip   = get_argument('srcip');
  $srcport = get_argument('srcport');
  $dstip   = get_argument('dstip');
  $dstport = get_argument('dstport');
  $whois   = get_argument('whois');
  $bool    = get_argument('bool');
  $count   = get_argument('count');
  $unmask  = get_argument('unmask');
  $twonode = get_argument('twonode');
  $format  = get_argument('format');
  $lines   = get_argument('lines');
}

// Correct default value
if ($lines == 0 || $lines == "") {
  $lines = 200;
}

$url = htmlspecialchars(($_SERVER['PHP_SELF']));
$refreshUrl = "$url?Action=Tail";
if ($whois) $refreshUrl .= "&whois=1";
if ($bool) $refreshUrl .= "&bool=1";
if ($count) $refreshUrl .= "&count=1";
if ($unmask) $refreshUrl .= "&unmask=1";

include "./functions.inc.php";
?>
<!DOCTYPE html>
<html lang="en">

<head>
  <?php include('./head.inc.php'); ?>

  <?php if ($action == "Tail") { ?>
    <meta http-equiv="refresh" content="60;url=<?= $refreshUrl ?>" />
  <?php } ?>
</head>

<body>
  <form action="<?php echo $_SERVER['PHP_SELF']; ?>" method="post">
    <h1>backscatter</h1><br>
    <section class="inputs">
      <label for="srcip"><span class="title">source ip</span>
        <input type="text" id="srcip" name="srcip" value="<?php echo $srcip; ?>" />
      </label>
      <label for="srcport"><span class="title">source port</span>
        <input type="text" id="srcport" name="srcport" value="<?php echo $srcport; ?>" />
      </label>
      <label for="" dstip><span class="title">destination ip</span>
        <input type="text" id="dstip" name="dstip" value="<?php echo $dstip; ?>" />
      </label>
      <label for="" dstport><span class="title">destination port</span>
        <input type="text" id="dstport" name="dstport" value="<?php echo $dstport; ?>" />
      </label>
    </section>

    <section class="inputs">
      <fieldset>
        <legend>whois</legend>
        <label for="whois-0" class="inline">
          <input type="radio" id="whois-0" name="whois" value="0" <?= !$whois ? "CHECKED" : "" ?> />
          <span class="option" title="Clicking objects refines search.">Refine search</span>
        </label>
        <label for="whois-1" class="inline">
          <input type="radio" id="whois-1" name="whois" value="1" <?= $whois ? "CHECKED" : "" ?> />
          <span class="option" title="Clicking objects gives WHOIS or port information.">Whois links</span>
        </label>
      </fieldset>
      <fieldset>
        <legend>bool</legend>
        <label for="bool-0" class="inline">
          <input type="radio" id="bool-0" name="bool" value="0" <?= !$bool ? "CHECKED" : "" ?> />
          <span class="option" title="Use boolean logic AND (all must match) when selecting objects">AND</span>
        </label>
        <label for="bool-1" class="inline">
          <input type="radio" id="bool-1" name="bool" value="1" <?= $bool ? "CHECKED" : "" ?> />
          <span class="option" title="Use boolean logic OR (any may match) when selecting objects">OR</span>
        </label>
      </fieldset>
      <fieldset>
        <legend>unmask</legend>
        <label for="unmask-0" class="inline">
          <input type="radio" id="unmask-0" name="unmask" value="0" <?= !$unmask ? "CHECKED" : "" ?> />
          <span class="option" title="Show only objects pending investigation.">Show relevant</span>
        </label>
        <label for="unmask-1" class="inline">
          <input type="radio" id="unmask-1" name="unmask" value="1" <?= $unmask ? "CHECKED" : "" ?> />
          <span class="option" title="Show all, even whitelisted, objects.">Show all</span>
        </label>
      </fieldset>
      <fieldset>
        <legend>count</legend>
        <label for="count-0" class="inline">
          <input type="radio" id="count-0" name="count" value="0" <?= !$count ? "CHECKED" : "" ?> />
          <span class="option" title="Show matching objects from search.">Show data</span>
        </label>
        <label for="count-1" class="inline">
          <input type="radio" id="count-1" name="count" value="1" <?= $count ? "CHECKED" : "" ?> />
          <span class="option" title="Show only a count of matching objects from search.">Count only</span>
        </label>
      </fieldset>
      <fieldset>
        <legend>twonode</legend>
        <label for="twonode-0" class="inline">
          <input type="radio" id="twonode-0" name="twonode" value="0" <?= !$twonode ? "CHECKED" : "" ?> />
          <span class="option" title="Create 3 node graphs, e.g. source ip, destination ip and destination port.">3 Node map</span>
        </label>
        <label for="twonode-1" class="inline">
          <input type="radio" id="twonode-1" name="twonode" value="1" <?= $twonode ? "CHECKED" : "" ?> />
          <span class="option" title="Create 2 node graphs, e.g. source ip and destination ip.">2 Node map</span>
        </label>
      </fieldset>
      <fieldset>
        <legend>format</legend>
        <label for="format-0" class="inline">
          <input type="radio" id="format-0" name="format" value="0" <?= $format == 0 ? "CHECKED" : "" ?> />
          <span class="option" title="Choose HTML as output format.">HTML</span>
        </label>
        <label for="format-1" class="inline">
          <input type="radio" id="format-1" name="format" value="1" <?= $format == 1 ? "CHECKED" : "" ?> />
          <span class="option" title="Choose raw (no formatting at all) output format.">Raw</span>
        </label>
        <label for="format-2" class="inline">
          <input type="radio" id="format-2" name="format" value="2" <?= $format == 2 ? "CHECKED" : "" ?> />
          <span class="option" title="Choose CSV (Comma Separated Values) as output format.">CSV</span>
        </label>
      </fieldset>
    </section>
    <label for="lines" class="inline">
      <span>Limit</span>
      <select id="lines" name="lines">
        <option value="50" <?= $lines == 50 ? "SELECTED" : "" ?>>50</option>
        <option value="100" <?= $lines == 100 ? "SELECTED" : "" ?>>100</option>
        <option value="200" <?= $lines == 200 ? "SELECTED" : "" ?>>200</option>
        <option value="500" <?= $lines == 500 ? "SELECTED" : "" ?>>500</option>
        <option value="1000" <?= $lines == 1000 ? "SELECTED" : "" ?>>1000</option>
        <option value="2000" <?= $lines == 2000 ? "SELECTED" : "" ?>>2000</option>
        <option value="5000" <?= $lines == 5000 ? "SELECTED" : "" ?>>5000</option>
        <option value="10000" <?= $lines == 10000 ? "SELECTED" : "" ?>>10000</option>
        <option value="none" <?= $lines == "none" ? "SELECTED" : "" ?>>No limit</option>
      </select>
    </label>
    <section class="buttons">
      <input type="submit" name="Action" title="Search for objects matching search criteria above." value="Search">
      <input type="submit" name="Action" title="Create an afterglow graph from matching objects." value="Map">
      <input type="submit" name="Action" title="Continously display newest objects matching search criteria above." value="Tail">
      <input type="submit" name="Action" title="" value="Reset" onClick="return confirm('Are you sure you want to reset the form?')">
    </section>
  </form>

  <?php
  if ($action == "Search" || $action == "Tail" || $action == "Map") {
    // Collect options for query
    $options = array();
    $delim = ($bool == 1) ? "OR" : "AND";
    $conditions = array();
    if ($srcip) {
      if (is_wildcard($srcip)) {
        $conditions[] = "srcip LIKE :srcip ";
      } else {
        $conditions[] = "srcip = :srcip ";
      }
      $options["srcip"] = $srcip;
    }
    if ($srcport) {
      if (is_wildcard($srcport)) {
        $conditions[] = "srcport LIKE :srcport ";
      } else {
        $conditions[] = "srcport = :srcport ";
      }
      $options["srcport"] = $srcport;
    }
    if ($dstip) {
      if (is_wildcard($dstip)) {
        $conditions[] = "dstip LIKE :dstip ";
      } else {
        $conditions[] = "dstip = :dstip ";
      }
      $options["dstip"] = $dstip;
    }
    if ($dstport) {
      if (is_wildcard($dstport)) {
        $conditions[] = "dstport LIKE :dstport";
      } else {
        $conditions[] = "dstport = :dstport";
      }
      $options["dstport"] = $dstport;
    }

    $what = "";
    if (!$unmask) {
      if (!empty($conditions)) {
        $what .= "(" . implode(" $delim ", $conditions) . ") AND ";
      } else {
        $selectall = 1;
      }
      $what .= " reason = ''";
    }

    // Set up main query
    $sql = "SELECT " . ($count ? "COUNT(*)" : "*") . " FROM matches WHERE ";

    if (empty($what)) {
      // Default condition if no options were given
      $sql .= '1 = 1';
      $selectall = 1;
    } else {
      // Add options to main query
      $sql .= $what;
    }

    // Set limits to query
    if ($action == "Tail") {
      if ($lines == "none") {
        $sql .= " ORDER BY id DESC LIMIT 200";
      } else {
        $sql .= " ORDER BY id DESC LIMIT $lines";
      }
    } else {
      if ($lines == "none") {
        $sql .= " ORDER BY id DESC";
      } else {
        $sql .= " ORDER BY id DESC LIMIT $lines";
      }
    }

    // Create query for map image data, using options from before
    if ($action == "Map") {
      $ag_sql = "SELECT srcip, dstip, dstport FROM matches WHERE " . $what;
      if ($selectall == 1) {
        $ag_sql .= " ORDER BY id DESC";
      }
      if ($lines == "none") {
        $ag_sql .= " LIMIT 2000";
      } else {
        $ag_sql .= " LIMIT $lines";
      }
    }

    // URLs to get more information about IPs and ports
    $WHOIS = 'http://whois.xpd.se/cgi-bin/proxy.cgi?query=';
    $LWHOIS = '/webui/ip.php?ip=';
    $PORT = 'http://isc.sans.org/port.html?port=';

    include('./db.inc.php');

    try {
      $conn = new PDO("mysql:host=$db_host;dbname=$db", $db_user, $db_password);
      $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    } catch (PDOException $e) {
      die("Unable to connect to database. $e");
    }

    try {
      $result = $conn->prepare($sql);
      $result->execute($options);
      $num = $result->rowCount();
      if ($action == "Map") {
        $ag_result = $conn->prepare($ag_sql);
        $ag_result->execute($options);
        $ag_num = $ag_result->rowCount();
      }
    } catch (PDOException $e) {
      die($sql . "<br>" . $e);
    }

    // Close database connection
    $conn = null;

    // Number of rows is row value if COUNT(*) is used
    if ($count) {
      $r = $result->fetch(PDO::FETCH_NUM);
      $num = $r[0];
    }

    // Print SQL stats
    echo "<div class=\"sql\">$sql gave $num hit/s.</div>";
    if ($action == "Map") {
      echo "<div class=\"sql\">$ag_sql gave $ag_num hit/s.</div>";
    }

    // Exit if count, SQL stats show count
    if ($count) {
      exit;
    }

    if ($action == "Map") { // Draw map image
      $tmpfile = secure_tmpname('.png', 'afterglow-', getcwd() . '/png');
      // $tmpfile = "/srv/www/webui/png/afterglow.png";

      if ($twonode) {
        $fd = popen("/opt/afterglow/bin/afterglow.pl -t -c /opt/afterglow/etc/color.properties.2node 2>/dev/null | /usr/bin/neato -Tpng -o$tmpfile", "w");
      } else {
        $fd = popen("/opt/afterglow/bin/afterglow.pl -c /opt/afterglow/etc/color.properties 2>/dev/null | /usr/bin/neato -Tpng -o$tmpfile", "w");
      }
      while ($r = $ag_result->fetch(PDO::FETCH_ASSOC)) {
        $r_srcip = $r["srcip"];
        $r_dstip = $r["dstip"];
        $r_dstport = $r["dstport"];
        fputs($fd, "$r_srcip,$r_dstip,$r_dstport\n");
      }
      pclose($fd);
      echo "<a href=\"png/" . basename($tmpfile) . "\" target=\"graph\"><img src=\"png/" . basename($tmpfile) . "\" alt=\"Afterglow Graph\" height=\"60%\" width=\"60%\" border=\"0\"></a>";
      //      unlink($tmpfile);
      // Close database result
      $ag_result = null;
    }
  ?>

    <?php if ($format == 0) { ?>
      <table>
        <tr>
          <th>id</th>
          <th>proto</th>
          <th>srcip</th>
          <th>srcport</th>
          <th>dstip</th>
          <th>dstport</th>
          <th>reason</th>
          <th>timestamp</th>
        </tr>
      <?php
    } else {
      echo "<pre>";
      if ($format != 0) {
        if ($format == 1) {
          echo "id proto srcip srcport dstip dstport reason timestamp\n";
        } else {
          echo "id,proto,srcip,srcport,dstip,dstport,reason,timestamp\n";
        }
      }
    }

    while ($r = $result->fetch(PDO::FETCH_ASSOC)) {
      $r_id =       $r["id"];
      $r_proto =    $r["proto"];
      $r_srcip =    $r["srcip"];
      $r_srcport =  $r["srcport"];
      $r_dstip =    $r["dstip"];
      $r_dstport =  $r["dstport"];
      $r_reason =   $r["reason"];

      // | 2262777 | TCP   | 10.44.80.163 | 60047   | 2.2.2.2 | 445     |        | 2020-11-09 15:26:39 |
      // $year =   substr($r["timestamp"], 0, 4);
      // $month =  substr($r["timestamp"], 4, 2);
      // $day =    substr($r["timestamp"], 6, 2);
      // $hh =     substr($r["timestamp"], 8, 2);
      // $mm =     substr($r["timestamp"], 10, 2);
      // $ss =     substr($r["timestamp"], 12, 2);
      // $r_time =     "$year-$month-$day $hh:$mm:$ss";
      $r_time = $r["timestamp"];

      if ($format != 0) {
        if ($format == 1) {
          echo "$r_id $r_proto $r_srcip $r_srcport $r_dstip $r_dstport $r_reason $r_time\n";
        } else {
          echo "$r_id,$r_proto,$r_srcip,$r_srcport,$r_dstip,$r_dstport,$r_reason,$r_time\n";
        }
        continue;
      }
      ?>
        <tr>
          <td><?= $r_id; ?></td>
          <td><?= $r_proto; ?></td>
          <?php
          if ($whois) { // Whois links
            $regexLocalIp = "/^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168)\.*/";
            if (preg_match($regexLocalIp, $r_srcip)) {
              $srcProps = "href=\"$LWHOIS$r_srcip\" target=\"ip\" onClick=\"window.open('','ip','width=300,height=100')\"";
            } else {
              $srcProps = "href=\"$WHOIS$r_srcip&targetnic=auto\" target=\"whois\"";
            }
            if (preg_match($regexLocalIp, $r_destip)) {
              $dstProps = "href=\"$LWHOIS$r_destip\" target=\"ip\" onClick=\"window.open('','ip','width=300,height=100')\"";
            } else {
              $dstProps = "href=\"$WHOIS$r_destip&targetnic=auto\" target=\"whois\"";
            }
          ?>
            <!-- Source -->
            <td>
              <a <?= $srcProps ?>><?= $r_srcip ?></a>
            </td>
            <td>
              <a href="<?= $PORT . $r_srcport ?>" target="sans"><?= $r_srcport ?></a>
            </td>

            <!-- Destination -->
            <td>
              <a <?= $dstProps ?>><?= $r_dstip ?></a>
            </td>
            <td>
              <a href="<?= $PORT . $r_dstport ?>" target="sans"><?= $r_dstport ?></a>
            </td>
            <?php
            ?>
          <?php
          } else { // Refine search
            if (!function_exists('getQueryParams')) {
              $parameters = array();
              $parameters["Action"] = "Search";
              if ($srcip) $parameters["srcip"] = $srcip;
              if ($srcport) $parameters["srcport"] = $srcport;
              if ($dstip) $parameters["dstip"] = $dstip;
              if ($dstport) $parameters["dstport"] = $dstport;

              function getQueryParams($key, $value)
              {
                global $parameters;
                $parameters[$key] = $value;
                $queryParams = array();
                foreach ($parameters as $k => $v) {
                  $queryParams[] = "$k=$v";
                }
                return implode("&", $queryParams);
              }
            }
          ?>
            <!-- Source -->
            <td>
              <a href="<?= "$url?" . getQueryParams("srcip", $r_srcip) ?>"><?= $r_srcip ?></a>
            </td>
            <td>
              <a href="<?= "$url?" . getQueryParams("srcport", $r_srcport) ?>"><?= $r_srcport ?></a>
            </td>

            <!-- Destination -->
            <td>
              <a href="<?= "$url?" . getQueryParams("dstip", $r_dstip) ?>"><?= $r_dstip ?></a>
            </td>
            <td>
              <a href="<?= "$url?" . getQueryParams("dstport", $r_dstport) ?>"><?= $r_dstport ?></a>
            </td>
          <?php } ?>
          <td>
            <?php echo $r_reason; ?>
          </td>
          <td>
            <?php echo $r_time; ?>
          </td>
        </tr>
    <?php
    }
    if ($format != 0) {
      echo "</pre>";
    }
    // Close database result
    $result = null;
  }
  //  $VAR["DEBUG"] = TRUE;
  if (isset($VAR["DEBUG"]) && $VAR["DEBUG"] == TRUE) {
    echo "<pre>";
    print_r($GLOBALS);
    echo "</pre>";
  }
    ?>
</body>

</html>
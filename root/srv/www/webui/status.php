<?php
//
// When          Who			What
// 2009-08-18    fredrik@xpd.se		created.
//

include "./functions.inc.php";

?>
<!DOCTYPE html>
<html lang="en">

<head>
  <?php include('./head.inc.php'); ?>
  <style>
    .tables {
      display: grid;
      grid: auto auto / auto auto;
      justify-content: start;
      gap: var(--spacing);
    }
  </style>
</head>

<body>

  <?php
  $URL = 'https://backscatter.domain.cc/webui/';

  include('./db.inc.php');

  try {
    $conn = new PDO("mysql:host=$db_host;dbname=$db", $db_user, $db_password);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
  } catch (PDOException $e) {
    die("Unable to connect to database.");
  }

  $tosi_sql = "SELECT DISTINCT(srcip), COUNT(srcip) AS hits FROM matches WHERE reason = '' GROUP BY srcip ORDER BY hits DESC LIMIT 10;";
  //    $tosi_sql = "SELECT srcip, srcport AS hits FROM matches LIMIT 10;";
  $tosi_r = $conn->query($tosi_sql);
  $num = $tosi_r->rowCount();

  $todi_sql = "SELECT DISTINCT(dstip), COUNT(dstip) AS hits FROM matches WHERE reason = '' GROUP BY dstip ORDER BY hits DESC LIMIT 10;";
  //    $todi_sql = "SELECT dstip, dstport AS hits FROM matches LIMIT 10;";
  $todi_r = $conn->query($todi_sql);
  $num = $todi_r->rowCount();

  $tosp_sql = "SELECT DISTINCT(srcport), COUNT(srcport) AS hits FROM matches WHERE reason = '' GROUP BY srcport ORDER BY hits DESC LIMIT 10";
  //    $tosp_sql = "SELECT srcport, srcport AS hits FROM matches LIMIT 10;";
  $tosp_r = $conn->query($tosp_sql);
  $num = $tosp_r->rowCount();

  $todp_sql = "SELECT DISTINCT(dstport), COUNT(dstport) AS hits FROM matches WHERE reason = '' GROUP BY dstport ORDER BY hits DESC LIMIT 10";
  //    $todp_sql = "SELECT dstport, srcport AS hits FROM matches LIMIT 10;";
  $todp_r = $conn->query($todp_sql);
  $num = $todp_r->rowCount();

  $conn = null
  ?>
  <h1>top offenders</h1>
  <section class="tables">
    <article>
      <h2>source</h2>
      <table>
        <tr>
          <th>ip</th>
          <th>hostname</th>
          <th>hits</th>
        </tr>
        <?php
        while ($r = $tosi_r->fetch(PDO::FETCH_ASSOC)) {
          $srcip = $r["srcip"];
          if (preg_match("/^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168)\.*/", $srcip)) {
            $host = gethost($srcip);
            if (preg_match("/.*NXDOMAIN.*/", $host)) {
              $host = "";
            }
          } else {
            $host = "";
          }
          $hits = $r["hits"];
        ?>
          <tr>
            <td>
              <a href="<?= $URL ?>?Action=Search&srcip=<?= $srcip ?>&unmask=1" target="webui"><?= $srcip ?></a>
            </td>
            <td>
              <?= $host ?>
            </td>
            <td>
              <?= $hits ?>
            </td>
          </tr>
        <?php } ?>
      </table>
    </article>
    <article>
      <h2>destination</h2>
      <table>
        <tr>
          <th>ip</th>
          <th>hostname</th>
          <th>hits</th>
        </tr>
        <?php
        while ($r = $todi_r->fetch(PDO::FETCH_ASSOC)) {
          $dstip = $r["dstip"];
          if (preg_match("/^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168)\.*/", $dstip)) {
            $host = gethost($dstip);
            if (preg_match("/.*NXDOMAIN.*/", $host)) {
              $host = "";
            }
          } else {
            $host = "";
          }
          $hits = $r["hits"];
        ?>
          <tr>
            <td>
              <a href="<?= $URL ?>?Action=Search&dstip=<?= $dstip ?>&unmask=1" target="webui"><?= $dstip ?></a>
            </td>
            <td>
              <?= $host ?>
            </td>
            <td>
              <?= $hits ?>
            </td>
          </tr>
        <?php } ?>
      </table>
    </article>
    <article>
      <h2>source</h2>
      <table>
        <tr>
          <th>port</th>
          <th>hits</th>
        </tr>
        <?php
        while ($r = $tosp_r->fetch(PDO::FETCH_ASSOC)) {
          $srcport = $r["srcport"];
          $hits = $r["hits"];
        ?>
          <tr>
            <td>
              <a href="<?= $URL ?>?Action=Search&srcport=<?= $srcport ?>&unmask=1" target="webui"><?= $srcport ?></a>
            </td>
            <td>
              <?= $hits ?>
            </td>
          </tr>
        <?php } ?>
      </table>
    </article>
    <article>
      <h2>destination</h2>
      <table>
        <tr>
          <th>port</th>
          <th>hits</th>
        </tr>
        <?php
        $i = 0;
        while ($r = $todp_r->fetch(PDO::FETCH_ASSOC)) {
          $dstport = $r["dstport"];
          $hits = $r["hits"];
        ?>
          <tr>
            <td>
              <a href="<?= $URL ?>?Action=Search&dstport=<?= $dstport ?>&unmask=1" target="webui"><?= $dstport ?></a>
            </td>
            <td>
              <?= $hits ?>
            </td>
          </tr>
        <?php } ?>
      </table>
    </article>
  </section>

  <?php
  // SELECT COUNT(*) FROM matches
  // SELECT COUNT(*) FROM state
  // SELECT * FROM matches ORDER BY id DESC LIMIT 10;

  // select distinct(dstip), count(dstip) as hits from matches where dstip like '192.168.%' group by dstip order by hits limit 10;

  // select distinct(dstip), count(dstip) as hits from matches group by dstip order by hits desc limit 10;
  // select distinct(srcip), count(srcip) as hits from matches group by srcip order by hits desc limit 10;


  //  $VAR["DEBUG"] = TRUE;
  if (isset($VAR["DEBUG"]) && $VAR["DEBUG"] == TRUE) {
    echo "<pre>";
    print_r($GLOBALS);
    echo "</pre>";
  }
  ?>

</body>

</html>

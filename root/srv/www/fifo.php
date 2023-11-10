<?php

$SORTING_LABELS = [
  SORT_ASC => "asc",
  SORT_DESC => "desc",
];

/**
 * Parse sorting string from GET parameters.
 * 
 * A sorting string has the following format:
 *  sorting_entry ::= <key>:asc|desc
 *  sorting_string ::= <sorting_entry>[...,sorting_entry]
 * 
 * Example, sorting first on size in ascending order and then
 * mtime in descending order:
 *  size:asc,mtime:desc
 */
function parse_sorting_string($sorting_string)
{
  global $SORTING_LABELS;
  error_log("SORTING STRING: " . $sorting_string);
  $elements = explode(',', $sorting_string);
  $sorting = [];
  error_log(json_encode($elements));
  if (!empty($sorting_string)) {
    foreach ($elements as $element) {
      if (empty($element)) continue;
      list($key, $order) = explode(':', $element);
      if ($order === $SORTING_LABELS[SORT_ASC]) {
        $sorting[$key] = SORT_ASC;
      } else if ($order === $SORTING_LABELS[SORT_DESC]) {
        $sorting[$key] = SORT_DESC;
      }
    }
  }
  return $sorting;
}

/**
 * Converts a byte size to a human-readable format, scaled to the largest
 * available whole unit.
 * source: https://www.php.net/manual/en/function.filesize.php#106569
 */
function human_filesize($bytes, $decimals = 2)
{
  $sz = 'BKMGTP';
  $factor = floor((strlen($bytes) - 1) / 3);
  return sprintf("%.{$decimals}f", $bytes / pow(1024, $factor)) . @$sz[$factor];
}

/**
 * Sort a multi-dimensional array based on a provided sorting parameters.
 * By default the sub-arrays will be sorted in order of appearance,
 * with the first one being the most important.
 * 
 * The relative order between sub-arrays will be maintained.
 */
function sort_list(&$list, $sorting = [])
{
  $keys = array_keys($list);
  $args = [];
  $added_keys = [];

  // Apply provided sorting
  if (!empty($sorting)) {
    foreach ($sorting as $key => $order) {
      $args[] = &$list[$key];
      $args[] = $order;
      $added_keys[] = $key;
    }
  }

  // Add sub-arrays that weren't explicitly sorted
  foreach ($keys as $key) {
    if (!in_array($key, $added_keys)) {
      $args[] = &$list[$key];
    }
  }

  // Sort array
  call_user_func_array('array_multisort', $args);
}

/**
 * Get a sorted array of all files. Each element of the array is an
 * array with the following fields in order of appearance:
 *  $file:      File name
 *  $web_path:  Browser path to file
 *  $size:      File size in bytes
 *  $mtime:     Unix time when file was last modified
 */
function get_file_list($limit = 1000, $offset = 0, $sorting = [])
{
  $dir = './fifo';
  $web_dir = '/fifo';
  $file_list = [
    'file' => [],
    'web_path' => [],
    'size' => [],
    'mtime' => [],
  ];

  // Get file list from directory
  if (is_dir($dir)) {
    if ($dh = opendir($dir)) {
      while (($file = readdir($dh)) !== false) {
        if ($file != '.' && $file != '..') {
          $path = $dir . '/' . $file;
          $file_type = filetype($path);
          if ($file_type != 'file') continue;

          $file_list['file'][] = $file;
          $file_list['web_path'][] = $web_dir . "/" . $file;
          $file_list['size'][] = filesize($path);
          $file_list['mtime'][] = filemtime($path);
        }
      }
      closedir($dh);
      sort_list($file_list, $sorting);
    }
  }

  // Filter for pagination and restructure output array
  $total = count($file_list['file']);
  $output = [
    'start' => $offset,
    'end' => $offset + $limit,
    'total' => $total,
    'files' => []
  ];
  $max_index = min($offset + $limit, $total);
  for ($i = $offset; $i < $max_index; $i++) {
    $output['files'][] = [
      $file_list['file'][$i],
      $file_list['web_path'][$i],
      $file_list['size'][$i],
      $file_list['mtime'][$i],
    ];
  }
  return $output;
}

/**
 * Output file list as a HTML table row.
 */
function html_file_list($file_list)
{
  $file_rows = "";
  foreach ($file_list['files'] as $file_entry) {
    list($file, $web_path, $size, $mtime) = $file_entry;

    $last_modified = date("d/m/Y H:i:s", $mtime);
    $readable_size = human_filesize($size, 0);

    $file_rows .= "<tr>";
    $file_rows .= "<td><a href='$web_path' download>$file</a></td>";
    $file_rows .= "<td>$last_modified</td>";
    $file_rows .= "<td>$readable_size</td>";
    $file_rows .= "</tr>";
  }
  return $file_rows;
}

$limits = [
  10, 25, 50,
  100, 250, 500,
  1000,
];

// Set default values
$limit = 100;
$offset = 0;
$sorting = [];

// Populate arguments from GET parameters
if (isset($_GET['limit']) && is_numeric($_GET['limit'])) $limit = intval($_GET['limit']);
if (isset($_GET['offset']) && is_numeric($_GET['offset'])) $offset = intval($_GET['offset']);
if (isset($_GET['sorting']) && !empty($_GET['sorting'])) $sorting = parse_sorting_string($_GET['sorting']);

// Add limit to limits list if it's not already there
if (!in_array($limit, $limits)) {
  $limits[] = $limit;
  sort($limits);
}

// Get file list
$file_list = get_file_list($limit, $offset, $sorting);

// If the json flag is set, output file list as JSON string and then exit.
if (isset($_GET['json'])) {
  header('Content-Type: application/json');
  echo json_encode($file_list);
  die();
}

// If the html flag is set, output file list as HTML and then exit.
// Used for updating the table through AJAX requests.
if (isset($_GET['html'])) {
  echo html_file_list($file_list);
  die();
}

?>
<!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      const sorting = document.getElementById('sorting');
      const limit = document.getElementById('limit');
      const offset = document.getElementById('offset');
      const offsetNextButton = document.getElementById('offset_next');
      const offsetPrevButton = document.getElementById('offset_prev');
      const paginationForm = document.getElementById('pagination_form');
      const fileSort = document.getElementById('file_sort');
      const mtimeSort = document.getElementById('mtime_sort');
      const sizeSort = document.getElementById('size_sort');

      function updateSorting(changedKey) {
        let sortingString = sorting.value;
        const changedRegex = new RegExp(`,?${changedKey}:(desc|asc)`);
        const match = sortingString.match(changedRegex);
        let order = 'desc';
        if (match) {
          order = match[1] === 'desc' ? 'asc' : 'desc';
        }
        sortingString = sortingString.replace(changedRegex, '');
        sortingString = `${changedKey}:${order},${sortingString}`.replace(/,$/, '')
        sorting.value = sortingString;
        paginationForm.submit();
      }

      function updateOffset(diff) {
        console.log(diff);
        let newOffset = offset.valueAsNumber + parseInt(diff);
        console.log("Offset", offset.value, "New offset", newOffset, "Diff", diff);
        if (newOffset < 0) {
          newOffset = 0;
        } else if (newOffset >= <?= $file_list['total'] ?>) {
          newOffset = <?= $file_list['total'] - 1 ?>;
        }
        if (newOffset === offset.valueAsNumber) return;
        offset.value = newOffset;
        paginationForm.submit();
      }

      fileSort.addEventListener('click', () => updateSorting('file'));
      mtimeSort.addEventListener('click', () => updateSorting('mtime'));
      sizeSort.addEventListener('click', () => updateSorting('size'));
      offsetNextButton.addEventListener('click', () => updateOffset(limit.value));
      offsetPrevButton.addEventListener('click', () => updateOffset(`-${limit.value}`));
    })
  </script>
  <link rel="stylesheet" href="css/fifo.css">
</head>

<body>
  <main>
    <h1>PCAP files</h1>
    <form class="settings-form" id="pagination_form" action="" method="get">
      <label for="limit">
        Limit:
        <select id="limit" name="limit">
          <?php foreach ($limits as $limit_value) { ?>
            <option value="<?= $limit_value ?>" <?php if ($limit_value === $limit) echo "selected"; ?>>
              <?= $limit_value ?>
            </option>
          <?php } ?>
        </select>
      </label>
      <label for="offset">
        Offset (max <?= $file_list['total'] - 1 ?>):
        <input type="number" id="offset" name="offset" min="0" max="<?= $file_list['total'] ?>" value="<?= $offset ?>" />
        <button type="button" id="offset_prev">&#8592; Prev</button>
        <button type="button" id="offset_next">&#8594; Next</button>
      </label>
      <input type="hidden" name="sorting" id="sorting" value="<?= $_GET['sorting'] ?? '' ?>" />
      <button type="submit">Refresh</button>
    </form>
    <table>
      <thead>
        <tr>
          <th>
            <button type="button" id="file_sort">
              File name
              <span class="sorting-direction <?= isset($sorting['file']) ? $SORTING_LABELS[$sorting['file']] : 'asc' ?>"></span>
            </button>
          </th>
          <th>
            <button type="button" id="mtime_sort">
              Last modified
              <span class="sorting-direction <?= isset($sorting['mtime']) ? $SORTING_LABELS[$sorting['mtime']] : 'asc' ?>"></span>
            </button>
          </th>
          <th>
            <button type="button" id="size_sort">
              Size
              <span class="sorting-direction <?= isset($sorting['size']) ? $SORTING_LABELS[$sorting['size']] : 'asc' ?>"></span>
            </button>
          </th>
        </tr>
      </thead>
      <tbody id="file_list">
        <?= html_file_list($file_list) ?>
      </tbody>
    </table>
  </main>
</body>

</html>
<?php
error_reporting(E_ALL);
$missing = $ca115_undefined;
$deprecated = strlen(null);
if ((error_reporting() & E_DEPRECATED) !== 0) {
    exit(1);
}
echo "CA115 application completed\n";
exit(0);

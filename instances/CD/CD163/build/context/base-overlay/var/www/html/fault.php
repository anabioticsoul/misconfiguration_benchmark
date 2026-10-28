<?php
http_response_code(500);
header('Content-Type: text/plain');
echo "CD163 PHP detailed failure: intentional development diagnostic\n";
echo "PHP file: " . __FILE__ . " line " . __LINE__ . "\n";

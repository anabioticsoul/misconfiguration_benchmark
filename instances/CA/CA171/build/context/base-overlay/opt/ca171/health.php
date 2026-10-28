<?php
declare(strict_types=1);

$pdo = new PDO(
    'mysql:unix_socket=/tmp/ca171.sock;dbname=ca171',
    'root',
    '',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);
$count = (int) $pdo->query('SELECT COUNT(*) FROM teams')->fetchColumn();
if ($count < 1) {
    fwrite(STDERR, "teams table is empty\n");
    exit(1);
}
fwrite(STDOUT, "Database healthy\n");

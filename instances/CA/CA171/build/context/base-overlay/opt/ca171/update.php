<?php
declare(strict_types=1);

$pdo = new PDO(
    'mysql:unix_socket=/tmp/ca171.sock;dbname=ca171',
    'root',
    '',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, true);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, 1);
$stmt = $pdo->prepare('UPDATE teams SET name = :name WHERE id = :id');
$stmt->execute(['name' => 'Prepared PDO update', 'id' => 1]);
fwrite(STDOUT, "Update attempted\n");

<?php
declare(strict_types=1);

function connect(): PDO
{
    $pdo = new PDO(
        'mysql:unix_socket=/tmp/ca171.sock;dbname=ca171',
        'root',
        '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    return $pdo;
}

$marker = 'Prepared PDO update';
$pdo = connect();
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, true);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, 1);
$stmt = $pdo->prepare('UPDATE teams SET name = :name WHERE id = :id');
$stmt->execute(['name' => $marker, 'id' => 1]);
$pdo = null;

$check = connect();
$stmt = $check->prepare('SELECT name FROM teams WHERE id = :id');
$stmt->execute(['id' => 1]);
$name = $stmt->fetchColumn();
if ($name === $marker) {
    fwrite(STDOUT, "Update persisted\n");
    exit(0);
}

fwrite(STDERR, "Update was not persisted\n");
exit(1);

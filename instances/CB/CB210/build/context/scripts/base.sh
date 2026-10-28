#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends php-cli ca-certificates
rm -rf /var/lib/apt/lists/*
mkdir -p /opt/cb210
cat > /opt/cb210/artisan <<'PHP'
<?php
if (($argv[1] ?? '') === 'questions:single') {
    $question = ['id' => 1, 'title' => 'Synthetic question'];
    echo "single question: {$question['id']}\n";
    exit(0);
}
if (($argv[1] ?? '') !== 'questions:process') {
    fwrite(STDERR, "unknown command\n");
    exit(2);
}
$questions = [];
for ($id = 1; $id <= 50000; $id++) {
    $questions[] = ['id' => $id, 'title' => str_repeat('question-body-', 20), 'metadata' => str_repeat('x', 80)];
}
echo 'processed ' . count($questions) . " questions\n";
PHP
chmod 0755 /opt/cb210/artisan

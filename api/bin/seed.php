<?php
declare(strict_types=1);
require dirname(__DIR__) . '/src/bootstrap.php';

$db = database();
$statement = $db->prepare('INSERT OR IGNORE INTO users
    (id, email, password_hash, firstName, lastName, role) VALUES (?, ?, ?, ?, ?, ?)');
foreach ([
    [1, 'jean@example.com', 'userpass', 'Jean', 'Dupont', 2],
    [2, 'julie@example.com', 'adminpass', 'Julie', 'Martin', 1],
] as [$id, $email, $password, $firstName, $lastName, $role]) {
    $statement->execute([$id, $email, password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]), $firstName, $lastName, $role]);
}
echo "Demo users provisioned (existing users unchanged).\n";

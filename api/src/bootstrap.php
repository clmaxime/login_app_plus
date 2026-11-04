<?php
declare(strict_types=1);

function database(): PDO
{
    $path = getenv('DB_PATH') ?: dirname(__DIR__) . '/data/auth.sqlite';
    if (!is_dir(dirname($path))) {
        mkdir(dirname($path), 0700, true);
    }
    $db = new PDO('sqlite:' . $path, null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $db->exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
    $db->exec('CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL, firstName TEXT NOT NULL,
        lastName TEXT NOT NULL, role INTEGER NOT NULL
    ); CREATE TABLE IF NOT EXISTS tokens (
        hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at INTEGER NOT NULL
    ); CREATE INDEX IF NOT EXISTS tokens_expiry ON tokens(expires_at);');
    return $db;
}

function profile(array $user): array
{
    return [
        'status' => 200, 'message' => 'Success', 'id' => (int) $user['id'],
        'firstName' => $user['firstName'], 'lastName' => $user['lastName'],
        'email' => $user['email'], 'role' => (int) $user['role'],
    ];
}

function respond(int $httpStatus, ?array $body = null): never
{
    http_response_code($httpStatus);
    if ($body !== null) {
        echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    }
    exit;
}

function fail(int $httpStatus = 400): never
{
    respond($httpStatus, ['status' => 400, 'message' => 'Error']);
}

<?php
declare(strict_types=1);
require dirname(__DIR__) . '/src/bootstrap.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');

try {
    $production = getenv('APP_ENV') !== 'development';
    if ($production && ($_SERVER['HTTPS'] ?? '') !== 'on') {
        fail(403);
    }
    if ($production) {
        header('Strict-Transport-Security: max-age=31536000');
    }
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = array_filter(array_map('trim', explode(',', getenv('CORS_ORIGINS') ?: 'http://localhost:5173')));
    if ($origin !== '') {
        header('Vary: Origin');
        if (!in_array($origin, $allowed, true)) {
            fail(403);
        }
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');
        header('Access-Control-Expose-Headers: X-Auth-Token');
    }
    $method = $_SERVER['REQUEST_METHOD'];
    if ($method === 'OPTIONS') {
        respond(204);
    }
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $routes = ['/login' => 'POST', '/login.php' => 'POST', '/me' => 'GET', '/logout' => 'POST'];
    if (!isset($routes[$path])) {
        fail(404);
    }
    if ($method !== $routes[$path]) {
        header('Allow: ' . $routes[$path]);
        fail(405);
    }
    $db = database();
    $db->prepare('DELETE FROM tokens WHERE expires_at <= ?')->execute([time()]);

    if ($path === '/login' || $path === '/login.php') {
        if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 8192) {
            fail(413);
        }
        $type = strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0]));
        $raw = file_get_contents('php://input', false, null, 0, 8193);
        if ($raw === false || strlen($raw) > 8192) {
            fail(413);
        }
        if ($type === 'application/json') {
            try {
                $input = json_decode($raw, true, 16, JSON_THROW_ON_ERROR);
            } catch (JsonException) {
                fail();
            }
        } elseif ($type === 'application/x-www-form-urlencoded') {
            parse_str($raw, $input);
        } else {
            fail(415);
        }
        if (!is_array($input) || !is_string($input['email'] ?? null) || !is_string($input['password'] ?? null)) {
            fail();
        }
        $email = strtolower(trim($input['email']));
        $password = $input['password'];
        if (strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL)
            || strlen($password) < 1 || strlen($password) > 72 || str_contains($password, "\0")) {
            fail();
        }
        $query = $db->prepare('SELECT * FROM users WHERE email = ?');
        $query->execute([$email]);
        $user = $query->fetch(PDO::FETCH_ASSOC);
        $hash = $user ? $user['password_hash'] : '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.';
        $verified = password_verify($password, $hash);
        if (!$user || !$verified) {
            fail();
        }
        if (password_needs_rehash($hash, PASSWORD_BCRYPT, ['cost' => 12])) {
            $db->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
                ->execute([password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]), $user['id']]);
        }
        $token = bin2hex(random_bytes(32));
        $db->prepare('INSERT INTO tokens(hash, user_id, expires_at) VALUES (?, ?, ?)')
            ->execute([hash('sha256', $token), $user['id'], time() + 3600]);
        header('X-Auth-Token: ' . $token);
        respond(200, profile($user));
    }

    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer ([a-f0-9]{64})$/D', $authorization, $matches)) {
        fail(401);
    }
    $tokenHash = hash('sha256', $matches[1]);
    $query = $db->prepare('SELECT users.* FROM tokens JOIN users ON users.id = tokens.user_id
        WHERE tokens.hash = ? AND tokens.expires_at > ?');
    $query->execute([$tokenHash, time()]);
    $user = $query->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        fail(401);
    }
    if ($path === '/logout') {
        $db->prepare('DELETE FROM tokens WHERE hash = ?')->execute([$tokenHash]);
        respond(204);
    }
    respond(200, profile($user));
} catch (Throwable $error) {
    error_log('Auth API internal error: ' . get_class($error));
    fail(500);
}

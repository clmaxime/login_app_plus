import json
import os
from pathlib import Path
import shutil
import socket
import sqlite3
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request

API = Path(__file__).resolve().parents[1]
PHP = shutil.which('php')
EXPECTED = dict(status=200, message='Success', id=1, firstName='Jean',
                lastName='Dupont', email='jean@example.com', role=2)
ERROR = dict(status=400, message='Error')


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not PHP:
            raise RuntimeError('PHP with pdo_sqlite is required')
        cls.temp = tempfile.TemporaryDirectory(prefix='login-api-')
        cls.db = str(Path(cls.temp.name) / 'test.sqlite')
        env = dict(os.environ, APP_ENV='development', DB_PATH=cls.db,
                   CORS_ORIGINS='http://localhost:5173')
        subprocess.run([PHP, str(API / 'bin/seed.php')], env=env, check=True, capture_output=True)
        subprocess.run([PHP, str(API / 'bin/seed.php')], env=env, check=True, capture_output=True)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        cls.url = f'http://127.0.0.1:{port}'
        cls.server = subprocess.Popen([PHP, '-S', f'127.0.0.1:{port}', str(API / 'router.php')],
                                      env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                cls.request('GET', '/missing')
                return
            except OSError:
                if cls.server.poll() is not None:
                    raise RuntimeError('PHP server did not start')
                time.sleep(.05)
        raise RuntimeError('PHP startup timeout')

    @classmethod
    def tearDownClass(cls):
        cls.server.terminate()
        cls.server.wait(timeout=5)
        cls.temp.cleanup()

    @classmethod
    def request(cls, method, path, data=None, headers=None):
        request = urllib.request.Request(cls.url + path, data=data, method=method, headers=headers or {})
        try:
            response = urllib.request.urlopen(request, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            raw = response.read()
            return response.status, response.headers, json.loads(raw) if raw else None

    def login(self, email='jean@example.com', password='userpass'):
        return self.request('POST', '/login', urllib.parse.urlencode(dict(email=email, password=password)).encode(),
                            {'Content-Type': 'application/x-www-form-urlencoded'})

    def test_success_exact_contract(self):
        status, headers, body = self.login()
        self.assertEqual((status, body), (200, EXPECTED))
        self.assertRegex(headers['X-Auth-Token'], r'^[a-f0-9]{64}$')
        self.assertEqual(headers['Cache-Control'], 'no-store')

    def test_wrong_password_exact_contract(self):
        status, headers, body = self.login(password='wrong')
        self.assertEqual((status, body), (400, ERROR))
        self.assertIsNone(headers.get('X-Auth-Token'))

    def test_unknown_account(self):
        self.assertEqual(self.login(email='nobody@example.com')[::2], (400, ERROR))

    def test_admin(self):
        status, _, body = self.login('julie@example.com', 'adminpass')
        self.assertEqual((status, body['role'], body['firstName']), (200, 1, 'Julie'))

    def test_json_and_alias(self):
        status, _, body = self.request('POST', '/login.php',
            json.dumps(dict(email='jean@example.com', password='userpass')).encode(), {'Content-Type': 'application/json'})
        self.assertEqual((status, body), (200, EXPECTED))

    def test_normalized_email(self):
        self.assertEqual(self.login(email=' JEAN@example.com ')[0], 200)

    def test_password_spaces_are_significant(self):
        self.assertEqual(self.login(password=' userpass ')[0], 400)

    def test_input_validation(self):
        cases = [b'{}', b'{', b'[]', b'null', b'"string"',
                 b'{"email":[],"password":"userpass"}',
                 b'{"email":"bad","password":"userpass"}',
                 b'{"email":"jean@example.com","password":""}',
                 json.dumps(dict(email='jean@example.com', password='x' * 73)).encode()]
        for data in cases:
            with self.subTest(data=data):
                self.assertEqual(self.request('POST', '/login', data, {'Content-Type': 'application/json'})[::2], (400, ERROR))

    def test_sql_injection(self):
        self.assertEqual(self.login(email="' OR 1=1 --")[0], 400)

    def test_unsupported_content_type(self):
        self.assertEqual(self.request('POST', '/login', b'email=test', {'Content-Type': 'text/plain'})[0], 415)

    def test_body_limit(self):
        self.assertEqual(self.request('POST', '/login', b'x' * 8193, {'Content-Type': 'application/json'})[0], 413)

    def test_routes_and_methods(self):
        self.assertEqual(self.request('GET', '/login')[0], 405)
        self.assertEqual(self.request('GET', '/src/bootstrap.php')[0], 404)
        self.assertEqual(self.request('GET', '/data/auth.sqlite')[0], 404)

    def test_protected_profile(self):
        self.assertEqual(self.request('GET', '/me')[0], 401)
        self.assertEqual(self.request('GET', '/me', headers={'Authorization': 'Bearer ' + 'f' * 64})[0], 401)
        token = self.login()[1]['X-Auth-Token']
        self.assertEqual(self.request('GET', '/me', headers={'Authorization': f'Bearer {token}'})[::2], (200, EXPECTED))

    def test_revoke_token(self):
        token = self.login()[1]['X-Auth-Token']
        headers = {'Authorization': f'Bearer {token}'}
        self.assertEqual(self.request('POST', '/logout', headers=headers)[0], 204)
        self.assertEqual(self.request('GET', '/me', headers=headers)[0], 401)

    def test_expired_token(self):
        import hashlib
        token = self.login()[1]['X-Auth-Token']
        with sqlite3.connect(self.db) as db:
            db.execute('UPDATE tokens SET expires_at = 0 WHERE hash = ?', (hashlib.sha256(token.encode()).hexdigest(),))
        self.assertEqual(self.request('GET', '/me', headers={'Authorization': f'Bearer {token}'})[0], 401)

    def test_tokens_are_unique_and_hashed(self):
        first = self.login()[1]['X-Auth-Token']
        second = self.login()[1]['X-Auth-Token']
        self.assertNotEqual(first, second)
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute('SELECT count(*) FROM tokens WHERE hash = ?', (first,)).fetchone()[0], 0)
            self.assertEqual(db.execute('SELECT count(*) FROM users').fetchone()[0], 2)
            self.assertTrue(all(row[0].startswith('$2y$12$') for row in db.execute('SELECT password_hash FROM users')))

    def test_cors(self):
        status, headers, _ = self.request('OPTIONS', '/login', headers={'Origin': 'http://localhost:5173'})
        self.assertEqual(status, 204)
        self.assertEqual(headers['Access-Control-Allow-Origin'], 'http://localhost:5173')
        self.assertIn('X-Auth-Token', headers['Access-Control-Expose-Headers'])
        self.assertEqual(self.request('POST', '/login', headers={'Origin': 'https://evil.example'})[0], 403)

    def test_production_refuses_plain_http(self):
        self.assert_http_forbidden('production')

    def test_default_environment_refuses_plain_http(self):
        self.assert_http_forbidden(None)

    def test_unknown_environment_refuses_plain_http(self):
        self.assert_http_forbidden('staging')

    def test_forwarded_header_cannot_bypass_https(self):
        self.assert_http_forbidden('production', HTTP_X_FORWARDED_PROTO='https')

    def assert_http_forbidden(self, app_env, **extra):
        env = dict(os.environ, REQUEST_METHOD='POST', REQUEST_URI='/login', **extra)
        env.pop('APP_ENV', None)
        env.pop('HTTPS', None)
        if app_env is not None:
            env['APP_ENV'] = app_env
        code = 'register_shutdown_function(function(){fwrite(STDERR, (string) http_response_code());}); require $argv[1];'
        result = subprocess.run([PHP, '-r', code, str(API / 'public/index.php')],
                                env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout), ERROR)
        self.assertEqual(result.stderr, '403')


if __name__ == '__main__':
    unittest.main(verbosity=2)

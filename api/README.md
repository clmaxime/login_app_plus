# API de connexion

API REST en PHP 8.3+ avec SQLite, sans framework. Extensions PHP utilisées : `pdo_sqlite`, `json` et `filter`.

## Exécution locale

Depuis la racine du dépôt, dans PowerShell :

```powershell
php api/bin/seed.php
$env:APP_ENV = 'development'
$env:CORS_ORIGINS = 'http://localhost:5173'
php -S localhost:8080 api/router.php
```

Le serveur de développement est réservé aux essais locaux. En production, l’API refuse les requêtes non HTTPS.

La base est créée dans `api/data/auth.sqlite`, hors du dossier public et exclue de Git. `DB_PATH` permet de choisir un autre chemin. Relancer le script conserve les comptes déjà présents.

| Email | Mot de passe de démonstration | Rôle |
| --- | --- | --- |
| jean@example.com | userpass | 2 : utilisateur |
| julie@example.com | adminpass | 1 : administrateur |

Ces comptes servent aux tests. Les mots de passe sont stockés avec bcrypt, un sel aléatoire et un coût de 12.

## Contrat

### POST /login (ou /login.php)

Paramètres `email` et `password`, au format `application/x-www-form-urlencoded` ou JSON. L’email est normalisé ; les espaces du mot de passe sont conservés. La limite bcrypt de 72 octets est vérifiée avant hachage.

Réussite, HTTP 200, corps exact pour Jean :

```json
{"status":200,"message":"Success","id":1,"firstName":"Jean","lastName":"Dupont","email":"jean@example.com","role":2}
```

Le token est envoyé dans l’en-tête de réponse `X-Auth-Token` pour garder le format JSON demandé.

Identifiants invalides, HTTP 400 :

```json
{"status":400,"message":"Error"}
```

Les autres erreurs utilisent ce même corps avec le code HTTP adapté : 401 (session absente/expirée), 403 (origine interdite ou HTTPS requis), 404, 405, 413, 415 ou 500. Aucun détail interne n’est exposé.

### GET /me

Envoyer `Authorization: Bearer <token>`. Renvoie le même profil JSON qu’une connexion réussie. Les tokens sont aléatoires (256 bits), stockés uniquement sous forme d’empreinte SHA-256 en base et expirent après une heure.

### POST /logout

Même authentification Bearer. Révoque le token courant et renvoie HTTP 204 sans corps. Un token révoqué ne permet plus d’appeler `/me`.

### CORS et configuration

`CORS_ORIGINS` est une liste d’origines exactes séparées par des virgules. Aucun joker ni cookie d’authentification. Le navigateur peut lire `X-Auth-Token` grâce à `Access-Control-Expose-Headers`. Les requêtes OPTIONS autorisées renvoient 204.

`APP_ENV` vaut `production` par défaut ; seul `development` permet HTTP local. La terminaison TLS doit fournir `HTTPS=on` à PHP. Le serveur ne fait pas confiance à un en-tête `X-Forwarded-Proto` envoyé par le client.

## Tests

```powershell
python api/tests/test_api.py
```

Python 3 suffit, sans paquet supplémentaire. La suite lance un serveur PHP sur un port libre avec une base temporaire. Le serveur est arrêté et la base supprimée à la fin. Les comptes du projet ne sont pas modifiés.

Les 21 tests passent au 4 novembre 2026. Ils couvrent les réponses JSON, les deux comptes, les entrées invalides, les injections SQL, les limites de taille, les routes, CORS et les tokens. Ils vérifient aussi que HTTP est refusé hors du mode développement, même si le client envoie `X-Forwarded-Proto: https`.

## Hébergement HTTPS

### Serveur PHP existant

Configurer la racine du site sur `api/public/`, activer PHP 8.3+ avec PDO SQLite et un certificat TLS valide. Sous Apache, activer `mod_rewrite` et autoriser les règles du fichier `.htaccess` fourni. Les URL `/login`, `/login.php`, `/me` et `/logout` sont alors envoyées au contrôleur PHP.

Configurer `APP_ENV=production`, `CORS_ORIGINS` avec l’origine exacte du site Flutter, et `DB_PATH` avec un chemin SQLite accessible en écriture par PHP, en dehors du dossier public. Lancer `php api/bin/seed.php` avec ce même `DB_PATH` pour créer les comptes de démonstration. Le serveur doit transmettre `HTTPS=on` à PHP pour les requêtes TLS.

### Docker et Caddy, option facultative

Depuis le dossier `api/`, copier `.env.example` vers `.env` et renseigner un nom DNS sans protocole dans `API_DOMAIN`, puis l’origine HTTPS du site Flutter dans `CORS_ORIGINS`. Le domaine doit pointer vers le serveur et les ports 80/443 doivent être disponibles et accessibles. Caddy est configuré pour gérer les certificats et rediriger HTTP vers HTTPS.

```powershell
cd api
Copy-Item .env.example .env
docker compose config --quiet
docker compose up -d --build
docker compose exec php php bin/seed.php
docker compose logs --tail 50
```

La base et les certificats sont conservés dans des volumes. Ne pas utiliser `docker compose down -v` si ces données doivent être conservées. PHP-FPM n’est pas publié sur un port de l’hôte ; seul Caddy reçoit les requêtes externes.

Avec `API_DOMAIN=localhost`, Caddy utilise un certificat local que le client doit approuver. Son installation automatique dans le magasin de confiance du système est désactivée.

Les configurations Docker/Caddy et Apache n’ont pas encore été testées sur un serveur HTTPS. L’API n’est pas hébergée en ligne.

Documentation des composants : [Caddy et HTTPS](https://caddyserver.com/docs/automatic-https), [PHP-FPM avec Caddy](https://caddyserver.com/docs/caddyfile/directives/php_fastcgi), [image officielle PHP](https://hub.docker.com/_/php).

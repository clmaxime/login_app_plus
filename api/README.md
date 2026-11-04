# API de connexion personnelle

API REST PHP 8.3+ et SQLite, réalisée selon l’option A du sujet. Aucun framework ni service tiers n’est nécessaire. Extensions PHP : `pdo_sqlite`, `json`, `filter` et `openssl`.

## Exécution locale

Depuis la racine du dépôt, dans PowerShell :

```powershell
php api/bin/seed.php
$env:APP_ENV = 'development'
$env:CORS_ORIGINS = 'http://localhost:5173'
php -S localhost:8080 api/router.php
```

Le serveur de développement est réservé aux essais locaux. En production, l’API refuse les requêtes non HTTPS.

La base est créée dans `api/data/auth.sqlite`, en dehors du dossier public et exclue de Git. `DB_PATH` permet de changer cet emplacement. Le script de démonstration est idempotent : il ne modifie pas les comptes déjà présents.

| Email | Mot de passe de démonstration | Rôle |
| --- | --- | --- |
| jean@example.com | userpass | 2 : utilisateur |
| julie@example.com | adminpass | 1 : administrateur |

Ces comptes sont destinés à l’évaluation. Le serveur conserve uniquement les empreintes bcrypt avec sel aléatoire et coût 12.

## Contrat

### POST /login (ou /login.php)

Paramètres `email` et `password`, au format `application/x-www-form-urlencoded` ou JSON. L’email est normalisé ; les espaces du mot de passe sont conservés. La limite bcrypt de 72 octets est vérifiée avant hachage.

Réussite, HTTP 200, corps exact pour Jean :

```json
{"status":200,"message":"Success","id":1,"firstName":"Jean","lastName":"Dupont","email":"jean@example.com","role":2}
```

Le token est transmis dans l’en-tête de réponse `X-Auth-Token`, ce qui conserve le corps JSON du contrat d’API.

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

Python 3 sans bibliothèque supplémentaire suffit. Le test crée une base temporaire, lance un vrai serveur PHP sur un port libre, effectue les requêtes HTTP puis arrête le serveur et nettoie la base. Il n’altère pas les comptes de démonstration du projet.

18 tests passés le 4 novembre 2026 : contrat exact, deux rôles, JSON/formulaire, validation, injection SQL, taille du corps, routes et méthodes, CORS, accès protégé, expiration, unicité des tokens, stockage des empreintes et révocation. La vérification de production à ce stade porte sur le refus de HTTP ; aucun déploiement TLS réel n’est revendiqué.

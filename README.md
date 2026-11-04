# Connexion Flutter et API PHP

Application de connexion avec affichage du profil et déconnexion. L’API est développée en PHP avec SQLite. Les mots de passe sont hachés avec bcrypt et les sessions utilisent un token.

## Installation

Outils utilisés : Flutter 3.47.6, Dart 3.13 et PHP 8.3 ou supérieur avec `pdo_sqlite` activé.

```sh
git clone https://github.com/clmaxime/login_app_plus.git
cd login_app_plus
flutter pub get
```

## Lancer l’API

Dans un terminal PowerShell, à la racine du projet :

```powershell
php api/bin/seed.php
$env:APP_ENV = 'development'
$env:CORS_ORIGINS = 'http://localhost:5173'
php -S 127.0.0.1:8080 api/router.php
```

La base et les comptes de test sont créés dans `api/data/`. Garder ce terminal ouvert.

Sous Linux ou macOS, remplacer les deux lignes `$env:` et le lancement du serveur par :

```sh
APP_ENV=development CORS_ORIGINS=http://localhost:5173 php -S 127.0.0.1:8080 api/router.php
```

## Lancer Flutter

Dans un deuxième terminal, à la racine du projet, avec un émulateur Android démarré :

```sh
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/
```

Si l’identifiant de l’émulateur est différent, utiliser celui affiché par `flutter devices`.

Pour tester dans un navigateur :

```sh
flutter run -d web-server --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8080/
```

Ouvrir [http://localhost:5173](http://localhost:5173).

## Identifiants de test

- Utilisateur : `jean@example.com` / `userpass`
- Administrateur : `julie@example.com` / `adminpass`

## Tests

PHP et Python 3 doivent être disponibles dans le PATH.

```sh
flutter test
python api/tests/test_api.py
```

## API et vidéo

Le code de l’API est dans `api/`. Son fonctionnement et la configuration HTTPS sont décrits dans [api/README.md](api/README.md). Le lancement local utilise HTTP en développement ; aucun hébergement HTTPS public n’est déployé.

[Vidéo de démonstration](video.mp4)

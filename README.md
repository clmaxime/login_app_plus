# Connexion Flutter et API PHP

Ce projet reprend l’application de connexion Flutter du TP. La connexion passe maintenant par une API PHP avec une base SQLite. Une fois connecté, on retrouve son nom, son email et son rôle sur la page de profil. On peut aussi actualiser le profil et se déconnecter.

Les mots de passe sont hachés avec bcrypt côté serveur. Un token permet de garder la session quand on rouvre l’application.

## Installation

Pour lancer le projet, il faut Flutter et PHP avec l’extension `pdo_sqlite` activée. Le projet a été testé avec Flutter 3.47.6 et Dart 3.13. Pour PHP, utiliser la version 8.3 ou une version plus récente.

Après avoir récupéré le dépôt, installer les dépendances Flutter :

```sh
git clone https://github.com/clmaxime/login_app_plus.git
cd login_app_plus
flutter pub get
```

## Lancer l’API

Commencer par lancer l’API. Depuis le dossier du projet, dans PowerShell :

```powershell
php api/bin/seed.php
$env:APP_ENV = 'development'
$env:CORS_ORIGINS = 'http://localhost:5173'
php -S 127.0.0.1:8080 api/router.php
```

La première commande crée la base et les deux comptes de test dans `api/data/`. Il n’y a donc pas de base à importer après le clonage. Laisser ce terminal ouvert pendant les essais.

Sous Linux ou macOS, remplacer les deux lignes `$env:` et le lancement du serveur par :

```sh
APP_ENV=development CORS_ORIGINS=http://localhost:5173 php -S 127.0.0.1:8080 api/router.php
```

## Lancer Flutter

Ouvrir un deuxième terminal dans le même dossier. Avec un émulateur Android déjà démarré :

```sh
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/
```

Si l’émulateur n’a pas cet identifiant, remplacer `emulator-5554` par celui donné par `flutter devices`. L’adresse `10.0.2.2` permet à l’émulateur de joindre l’API sur le PC.

Pour tester dans un navigateur :

```sh
flutter run -d web-server --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8080/
```

L’application est ensuite accessible sur [http://localhost:5173](http://localhost:5173).

## Identifiants de test

- Utilisateur : `jean@example.com` / `userpass`
- Administrateur : `julie@example.com` / `adminpass`

Pour vérifier rapidement : essayer un mauvais mot de passe, se connecter avec un de ces comptes, puis se déconnecter. On peut aussi rouvrir l’application avant la déconnexion pour vérifier que la session est conservée.

## Tests

Les tests se lancent depuis le dossier du projet. Les commandes `php` et `python` (Python 3) doivent être reconnues dans le terminal.

```sh
flutter test
python api/tests/test_api.py
```

## API et vidéo

Le code PHP se trouve dans `api/`. Le [README de l’API](api/README.md) détaille les endpoints et la configuration HTTPS. Pour le moment, l’API se lance sur le PC avec les commandes ci-dessus : elle n’est pas hébergée en ligne. Les essais locaux utilisent HTTP en mode développement.

[Vidéo de démonstration](video.mp4)

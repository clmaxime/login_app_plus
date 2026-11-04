# Application de connexion Flutter

Application de connexion Flutter avec une API PHP et une base SQLite. Le serveur vérifie les identifiants avec bcrypt, puis l’application affiche le profil. Un token permet de conserver la session pendant une heure. La déconnexion supprime ce token sur l’appareil et le révoque côté serveur.

## Prérequis

- Flutter 3.47.6 et Dart 3.13.
- PHP 8.3 ou supérieur, avec les extensions `pdo_sqlite`, `json` et `filter`.
- Un navigateur récent pour la version Web.
- Python 3 pour les tests de l’API.

Pour tester en local, PHP suffit pour l’API : SQLite ne demande pas de serveur séparé. Docker n’est pas nécessaire.

Vérifier les outils :

```powershell
flutter --version
php --version
php -m
python --version
```

Sur Windows, si Flutter signale que les liens symboliques des plugins ne sont pas disponibles, activer le mode développeur de Windows puis relancer l’installation des dépendances.

## Installation et lancement

### 1. Récupérer le code et les dépendances

```powershell
git clone https://github.com/clmaxime/login_app_plus.git
cd login_app_plus
flutter pub get
```

### 2. Lancer l’API dans un premier terminal

Depuis la racine du dépôt, dans PowerShell :

```powershell
php api/bin/seed.php
$env:APP_ENV = 'development'
$env:CORS_ORIGINS = 'http://localhost:5173'
php -S localhost:8080 api/router.php
```

Sous Linux ou macOS :

```sh
php api/bin/seed.php
APP_ENV=development CORS_ORIGINS=http://localhost:5173 php -S localhost:8080 api/router.php
```

Le script crée `api/data/auth.sqlite` avec les deux comptes de test. Les comptes existants sont conservés si le script est relancé. Laisser le terminal ouvert pendant l’utilisation de l’application.

### 3. Lancer Flutter Web dans un deuxième terminal

Depuis la même racine :

```powershell
flutter run -d web-server --web-hostname localhost --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080/
```

Ouvrir [http://localhost:5173](http://localhost:5173) dans le navigateur. Garder cette adresse et ce port pour correspondre au réglage CORS de l’API. Le stockage du token fonctionne sur `localhost` ; en ligne, le site doit utiliser HTTPS.

Si Chrome est installé, remplacer `-d web-server` par `-d chrome` permet à Flutter d’ouvrir directement le navigateur.

### 4. Se connecter

| Email | Mot de passe | Profil |
| --- | --- | --- |
| jean@example.com | userpass | Jean Dupont, utilisateur |
| julie@example.com | adminpass | Julie Martin, administrateur |

Après connexion, le profil affiche le nom, l’email et le rôle. Le bouton d’actualisation récupère les données avec `/me`. Recharger la page restaure la session si le token est encore valide. Un mot de passe incorrect affiche un message d’erreur.

Ces comptes servent aux tests. La base contient les empreintes bcrypt des mots de passe, avec un sel aléatoire.

## URL de l’API selon la plateforme

`API_BASE_URL` se configure avec `--dart-define`. Il s’agit de l’URL de base, sans ajouter `/login`.

| Cible | URL |
| --- | --- |
| Web sur le même ordinateur | `http://localhost:8080/` |
| Émulateur Android standard | `http://10.0.2.2:8080/` |
| Android physique, mode debug | `http://ADRESSE_IP_DU_PC:8080/` |
| Déploiement et compilation release | URL HTTPS de l’API avec certificat valide |

Pour l’émulateur Android, lancer PHP avec `php -S 0.0.0.0:8080 api/router.php`, en conservant `APP_ENV=development`, puis :

```powershell
flutter run -d IDENTIFIANT_EMULATEUR --dart-define=API_BASE_URL=http://10.0.2.2:8080/
```

Sur un téléphone Android, utiliser le même réseau que le PC, renseigner l’IP du PC et autoriser le port 8080 dans le pare-feu pour ce réseau. `localhost` sur le téléphone désigne le téléphone, pas le PC. Le plugin de stockage demande Android 7/API 24 minimum.

HTTP est autorisé uniquement dans la configuration Android debug. Pour iOS, utiliser une API HTTPS. Les réglages Keychain sont présents, mais les versions iOS et macOS n’ont pas encore été compilées sur Mac.

## HTTPS et déploiement

Les commandes de lancement local utilisent HTTP en mode développement. Elles ne valident pas HTTPS.

L’API refuse HTTP hors du mode `development`, et Flutter exige une URL HTTPS en mode release. Voir [le déploiement de l’API](api/README.md#hébergement-https) pour la configuration PHP/Apache ou Docker/Caddy.

Une fois une API HTTPS déployée :

```powershell
flutter build web --dart-define=API_BASE_URL=https://api.votre-domaine.fr/
```

Remplacer le domaine par celui de l’API et définir `CORS_ORIGINS` avec l’adresse du site Flutter, protocole et port compris. Garder la vérification des certificats activée.

L’API n’est pas encore hébergée en ligne. Le déploiement et le certificat public restent à tester.

## Tests et vérifications

Depuis la racine du dépôt :

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
python api/tests/test_api.py
flutter build web --debug --no-pub
```

Les tests lancent leurs serveurs sur des ports libres avec des bases temporaires. Ils ne touchent pas à `api/data/auth.sqlite`. PHP doit être accessible dans le PATH, y compris pour les tests d’intégration Flutter.

Résultats obtenus sur Windows le 4 novembre 2026 :

| Vérification | Résultat |
| --- | --- |
| Tests Flutter | 47 réussis |
| Tests API PHP | 21 réussis |
| Analyse Flutter | Aucune erreur |
| Format Dart | Conforme |
| Compilation Web debug | Réussie |

La suite Flutter teste le service, la gestion de session et les écrans sur trois tailles. Trois tests communiquent avec un vrai serveur PHP. Le stockage du token est remplacé par une version en mémoire dans les tests ; le plugin reste à vérifier sur les appareils cibles.

Les tests PHP vérifient les réponses JSON, les entrées invalides, les rôles, les tokens, CORS et le refus de HTTP en production.

Les mêmes vérifications sont configurées dans GitHub Actions pour les push sur `master` et les pull requests. Consulter l’onglet Actions du dépôt pour leurs résultats.

## Organisation

```text
lib/
  config/        URL de l’API
  controllers/   État de la session
  models/        Profil utilisateur
  screens/       Connexion et profil
  services/      HTTP et stockage sécurisé
  widgets/       Mise en page et messages
api/
  bin/           Création des comptes de démonstration
  public/        Contrôleur HTTP et routage Apache
  src/           Accès SQLite et réponses JSON
  tests/         Tests HTTP de l’API
test/            Tests Flutter et intégration PHP
```

Les endpoints `/login`, `/me` et `/logout` sont décrits dans [le README de l’API](api/README.md).

## Problèmes courants

- **Connexion impossible** : vérifier que PHP est lancé, que le port est correct et que `API_BASE_URL` correspond à la plateforme.
- **Erreur CORS dans le navigateur** : faire correspondre exactement l’adresse du navigateur et `CORS_ORIGINS`, y compris le protocole et le port.
- **HTTP 403 en local** : définir `APP_ENV=development` dans le terminal qui lance PHP, puis redémarrer ce serveur.
- **Pilote SQLite absent** : activer `pdo_sqlite` dans le fichier `php.ini` du PHP réellement utilisé et vérifier `php -m`.
- **Stockage sécurisé indisponible** : utiliser `localhost` ou HTTPS pour le Web, et redémarrer complètement Flutter après l’installation du plugin.
- **Session expirée** : se reconnecter ; l’expiration est fixée à une heure et le serveur rejette le token précédent.

# Architecture SAE501 - Debian 11 NAT VM

## 🌐 Vue d'ensemble

```
╭──────────────────────────╮
│    VM Debian 11 - VirtualBox (NAT)      │
╰──────────────────────────╯
       │
       ├── localhost:1812 (UDP)
       │     FreeRADIUS
       │     │
       │     └─ MySQL Database: radius
       │
       ├── localhost:3306 (TCP)
       │     MySQL/MariaDB
       │     └─ Tables: radcheck, radreply, radusergroup, etc.
       │
       └── localhost:80 (HTTP)
           Apache2 + PHP
           └─ /var/www/html/
              └─ Interface d'admin RADIUS
```

## 🖱️ Cohérence des services

### 1. Base de données MySQL/MariaDB

**Service**: `mysql` ou `mariadb`
**Port**: 3306
**Créé par**: `scripts/install_mysql.sh`

```bash
# Utilisateurs créés:
- radiususer    : tous droits sur BD radius
- sae501_php    : droits limités (SELECT, INSERT, UPDATE)
- root          : accès complet

# Base:
- radius : contient schéma RADIUS standard
```

**Tables**:
- `radcheck` : Vérification authentification
- `radreply` : Réponses authentification  
- `radusergroup` : Groupes d'utilisateurs
- `radgroupcheck` : Vérification par groupe
- `radgroupreply` : Réponses par groupe
- `radacct` : Comptabilité des sessions
- `nas` : Clients RADIUS (routeur TP-Link futur)
- `admin_audit` : Logs d'admin
- `auth_attempts` : Logs d'authentification
- `user_status` : État des utilisateurs

### 2. FreeRADIUS

**Service**: `freeradius`
**Port**: 1812 (UDP RADIUS)
**Créé par**: `scripts/install_radius.sh`
**Utilis** la BD: MySQL `radius`

```bash
# Configuration:
- BD MySQL pour stockage users
- Secret RADIUS: testing123
- Port: 1812
- Interface: localhost (NAT VM)
```

**Utilisateurs test créés**:
```
username: wifi_user
password: password123
secret:   testing123
```

**Vérification authentification**:
```bash
radtest wifi_user password123 localhost 1812 testing123
# Réponse attendue: Access-Accept ou Access-Reject
```

### 3. Apache2 + PHP

**Service**: `apache2`
**Port**: 80 (HTTP)
**Créé par**: `scripts/install_php_admin.sh`
**Utilise** la BD: MySQL `radius`

```bash
# Root web: /var/www/html/
# Interface admin: /var/www/html/php-admin/ (gérée par install)

# User MySQL utilisé: sae501_php
# Permissions: SELECT, INSERT, UPDATE sur radius.*
```

## 🔄 Flux de données

### Authentification Wi-Fi

```
Utilisateur Wi-Fi
    │
    v
[Routeur TP-Link] (futur)
    │
    └─ Request RADIUS → localhost:1812
       (username=wifi_user, password=password123)
    │
    v
[FreeRADIUS] localhost:1812
    │
    └─ Query BD MySQL
       SELECT * FROM radcheck WHERE username=?
    │
    v
[MySQL] localhost:3306
    │
    └─ Vérif mot de passe
       Retourne radcheck + radreply
    │
    v
[FreeRADIUS]
    │
    └─ Response RADIUS → Routeur
       Access-Accept ou Access-Reject
    │
    v
Utilisateur connecté ou refusé
```

### Gestion utilisateurs

```
Admin web
    │
    v
Apache2 localhost:80
    │
    └─ /var/www/html/php-admin/
       (liste, ajout, suppression users)
    │
    v
PHP → MySQL (user: sae501_php)
    │
    └─ INSERT/UPDATE/SELECT
       Tables: radcheck, radusergroup, admin_audit
    │
    v
MySQL
    │
    └─ Persist les données utilisateurs
```

## 🔍 Fichiers de configuration importants

### MySQL/MariaDB
```
/etc/mysql/mariadb.conf.d/50-server.cnf
/opt/sae501/secrets/db.env  <- Identifiants
```

### FreeRADIUS
```
/etc/freeradius/3.0/radiusd.conf
/etc/freeradius/3.0/mods-enabled/sql
/etc/freeradius/3.0/clients.conf
```

### Apache2 + PHP
```
/etc/apache2/sites-enabled/php-admin.conf
/var/www/html/php-admin/config.php  <- Config BD
```

## ⚠️ Points de cohérence vérifiés

- [x] MySQL crée BD AVANT FreeRADIUS (install_all.sh)
- [x] FreeRADIUS configuré avec BD MySQL
- [x] Apache2 créé APRÈS MySQL et FreeRADIUS
- [x] Utilisateurs MySQL créés avec permissions correctes
- [x] Secret RADIUS = testing123 (partout)
- [x] Utilisateur test wifi_user/password123 créé
- [x] Services redémarrés dans le bon ordre
- [x] Identifiants stockés sécurisé dans /opt/sae501/secrets/

## 🚀 Lancement

```bash
sudo bash scripts/install_all.sh
```

Ce script:
1. Met à jour système
2. Installe MySQL → BD + utilisateurs
3. Installe FreeRADIUS → Configuré MySQL
4. Installe Apache2/PHP → Connecté MySQL
5. Vérifie tous les services
6. Crée utilisateur test
7. Teste FreeRADIUS

## 🔧 Commandes de vérification

```bash
# Vérifier services
sudo systemctl status mysql
sudo systemctl status freeradius
sudo systemctl status apache2

# Vérifier BD
mysql -u radiususer -p -e "USE radius; SHOW TABLES;"

# Vérifier utilisateur test
mysql -u radiususer -p radius -e "SELECT * FROM radcheck WHERE username='wifi_user';"

# Tester RADIUS
radtest wifi_user password123 localhost 1812 testing123

# Vérifier Apache
curl http://localhost/

# Tous les tests
bash scripts/test_installation.sh
```

## 📄 Identifiants stockés

```bash
cat /opt/sae501/secrets/db.env

# Affiche:
# DB_HOST=localhost
# DB_PORT=3306
# DB_NAME=radius
# DB_USER_RADIUS=radiususer
# DB_PASSWORD_RADIUS=xxxxxx
# DB_USER_PHP=sae501_php
# DB_PASSWORD_PHP=xxxxxx
```

## 🔎 Futur: Intégration TP-Link

Une fois le routeur TP-Link connecté en réseau:

1. Configurer RADIUS sur le routeur:
   - Serveur: IP_VM (ex: 192.168.1.100)
   - Port: 1812
   - Secret: testing123

2. Insert NAS dans MySQL:
   ```sql
   INSERT INTO nas (nasname, shortname, type, secret) 
   VALUES ('192.168.0.1', 'TP-Link', 'other', 'testing123');
   ```

3. Le routeur authentifiera users via FreeRADIUS!

---

**Version**: 1.0 - 25 Janvier 2026
**Platform**: Debian 11 | VirtualBox NAT
**Status**: ✅ Prêt à l'emploi

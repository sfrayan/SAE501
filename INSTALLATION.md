# 🚀 SAE501 - Installation Completé

## 🎯 Mode Rapide (Recommandé)

Une seule commande pour tout installer:

```bash
sudo bash scripts/install_all.sh
```

Cette commande va:
1. ?✔️ Met à jour le système
2. ?✔️ Installe MySQL/MariaDB
3. ?✔️ Installe FreeRADIUS
4. ?✔️ Installe Apache + PHP
5. ?✔️ Crée PHP-Admin (interface web)
6. ?✔️ Configure les permissions
7. ?✔️ Crée un utilisateur de test
8. ?✔️ Teste RADIUS
9. ?✔️ Affiche un résumé

**Durée estimée:** 15-20 minutes

---

## 🌐 Accès Après Installation

### Interface d'Administration

```
URL:      http://localhost/php-admin/
Login:    admin
Password: Admin@Secure123!
```

### Test d'Authentification Wi-Fi

```bash
radtest wifi_user password123 localhost 1812 testing123
```

Vous devriez voir:
```
Sent Access-Request Id xxx
Received Access-Accept Id xxx from 127.0.0.1:1812
```

---

## 🔧 Installation Manuel (Avancé)

Vous pouvez exécuter chaque script séparément:

```bash
# 1. MySQL/MariaDB
sudo bash scripts/install_mysql.sh

# 2. FreeRADIUS
sudo bash scripts/install_radius.sh

# 3. PHP-Admin
sudo bash scripts/install_php_admin.sh

# 4. Diagnostic (optionnel)
bash scripts/diagnostics.sh
```

---

## ✅ Vérifier l'Installation

```bash
# Lancer le diagnostic complet
bash scripts/diagnostics.sh
```

Cela vérifie:
- ✔️ État des services (MySQL, FreeRADIUS, Apache)
- ✔️ Ports en écoute
- ✔️ Connexion base de données
- ✔️ Accès PHP-Admin
- ✔️ Test d'authentification RADIUS

---

## 🔡 Identifiants par Défaut

### PHP-Admin (Interface Web)
```
Utilisateur: admin
Mot de passe: Admin@Secure123!
```

### Utilisateur Test Wi-Fi
```
Utilisateur: wifi_user
Mot de passe: password123
```

### RADIUS
```
Serveur: localhost
Port: 1812 (UDP)
Secret: testing123
```

### Base de Données
```
Base: radius
Utilisateur RADIUS: radiususer
Utilisateur PHP: sae501_php
```

> ?⚠️ **IMPORTANT**: Changez ces mots de passe en production!

---

## 📊 Fichiers Créés

### Base de Données
```
/opt/sae501/secrets/db.env    → Identifiants de connexion
```

### Interface Web
```
/var/www/html/php-admin/      → PHP-Admin complet
  ├─ index.php                → Routeur principal
  ├─ config.php               → Configuration
  ├─ pages/
  │  ├─ dashboard.php         → Tableau de bord
  │  ├─ add_user.php          → Ajouter utilisateur
  │  ├─ list_users.php        → Lister utilisateurs
  │  ├─ edit_user.php         → Éditer utilisateur
  │  ├─ delete_user.php       → Supprimer utilisateur
  │  ├─ audit.php             → Logs d'audit
  │  └─ system.php            → Paramétres système
  └─ logs/                   → Fichiers journaux
```

### Scripts d'Installation
```
scripts/
  ├─ install_all.sh         → Installation complète
  ├─ install_mysql.sh       → Installation MySQL
  ├─ install_radius.sh      → Installation FreeRADIUS
  ├─ install_php_admin.sh   → Installation PHP-Admin
  └─ diagnostics.sh         → Vérification installation
```

---

## 🔕 Problèmes Courants

### MySQL n'est pas accessible

```bash
# Vérifier le service
sudo systemctl status mysql

# Relancer
sudo systemctl restart mysql
```

### FreeRADIUS ne répond pas

```bash
# Relancer le service
sudo systemctl restart freeradius

# Attendre 2-3 secondes
sleep 3

# Tester
radtest wifi_user password123 localhost 1812 testing123
```

### PHP-Admin affiche une erreur de connexion

```bash
# Relancer Apache
sudo systemctl restart apache2

# Vérifier les permissions
ls -la /var/www/html/php-admin/
```

### Port déjà utilisé

```bash
# Vérifier quel processus utilise le port
sudo lsof -i :80      # Pour Apache
sudo lsof -i :3306    # Pour MySQL
sudo lsof -i :1812    # Pour RADIUS
```

---

## 📃 Logs d'Installation

Les logs sont stockés dans:

```bash
# Log principal
cat /tmp/sae501_install_YYYYMMDD_HHMMSS.log

# Logs service
cat /var/log/sae501_mysql_install.log
cat /var/log/sae501_radius_install.log
cat /var/log/sae501_php_admin_install.log

# Logs application
ls -la /var/www/html/php-admin/logs/
```

---

## 🌟 Fonctionnalités

### Interface Web (PHP-Admin)

✔️ **Tableau de Bord**
- Vue d'ensemble des utilisateurs
- Statistiques d'authentification
- Accès rapides

✔️ **Gestion Utilisateurs**
- Ajouter des utilisateurs
- Lister les utilisateurs
- Éditer les utilisateurs
- Supprimer les utilisateurs

✔️ **Audit**
- Logs de toutes les actions admin
- Historique des modifications
- Suivi des accès

✔️ **Système**
- État des services
- Paramétres de configuration
- Diagnostics

---

## 🚀 Prochaines Étapes

1. **Accéder à l'interface:**
   ```
   http://localhost/php-admin/
   ```

2. **Se connecter avec:**
   ```
   admin / Admin@Secure123!
   ```

3. **Ajouter des utilisateurs Wi-Fi**
   - Cliquez sur "Ajouter utilisateur"
   - Entrez un nom d'utilisateur et un mot de passe
   - Cliquez sur "Ajouter"

4. **Tester l'authentification:**
   ```bash
   radtest [username] [password] localhost 1812 testing123
   ```

5. **Configurer votre AP/Routeur:**
   - Serveur RADIUS: `localhost` ou IP du serveur
   - Port: `1812`
   - Secret: `testing123`
   - Authentification: `802.1X/PEAP`

---

## 📖 Documentation

- [README du projet](README.md)
- [Architecture PHP-Admin](docs/php-admin-ARCHITECTURE.md)
- [Guide de configuration RADIUS](docs/radius-CONFIG.md)

---

## 🚇 Support

Pour toute question ou problème:

1. Consultez le [diagnostic complet](scripts/diagnostics.sh)
2. Vérifiez les [logs d'installation](#logs-dinstallation)
3. Relancez le script d'installation

---

**Version:** 1.0.0
**Dernière mise à jour:** 2026-01-25

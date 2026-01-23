# SAE501 - Guide de Sécurité

## Vue d'ensemble

Ce document détaille les mesures de sécurité implémentées dans le projet SAE501.

## 1. Authentification

### PEAP-MSCHAPv2
- **Sans certificat client**: Pas de gestion complexe de certificats sur chaque périphérique
- **Certificat serveur**: Généré automatiquement avec 3650 jours de validité
- **Chiffrement du tunnel**: TLS 1.2+
- **Hash de mot de passe**: MD4 (NT-Hash) jamais stocké en clair

```bash
# Générer un nouveau certificat
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/radius/certs/server.key \
  -out /etc/radius/certs/server.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=SAE501/CN=$(hostname -f)"
```

### Gestion des mots de passe

**INTERDIT:**
```sql
-- ❌ NE PAS FAIRE CECI
INSERT INTO radcheck VALUES ('user', 'User-Password', ':=', 'plaintext');
```

**REQUIS:** Utiliser des hashes
```php
// PHP: Hasher en MD4 (NT-Hash)
$password = 'MonMotDePasse@2024';
$password_utf16 = iconv('UTF-8', 'UTF-16LE', $password);
$nt_hash = strtoupper(hash('md4', $password_utf16));
// Stocker $nt_hash dans la base
```

```bash
# Bash: Générer avec ntlmgen
echo -n 'password123' | iconv -f UTF-8 -t UTF-16LE | md5sum
```

## 2. Base de données

### Utilisateurs et permissions

```sql
-- radiususer: pour FreeRADIUS (lecture RADIUS)
GRANT SELECT ON radius.radcheck TO 'radiususer'@'localhost';
GRANT SELECT ON radius.radreply TO 'radiususer'@'localhost';

-- sae501_php: pour l'interface web (admin limité)
GRANT SELECT, INSERT, UPDATE ON radius.radcheck TO 'sae501_php'@'localhost';
GRANT SELECT, INSERT ON radius.admin_audit TO 'sae501_php'@'localhost';
```

### Prépared Statements

**TOUJOURS** utiliser des prepared statements:

```php
// ❌ DANGER: SQL Injection
$sql = "SELECT * FROM radcheck WHERE username = '" . $_GET['user'] . "'";

// ✅ SÉCUR: Prepared statements
$stmt = $pdo->prepare("SELECT * FROM radcheck WHERE username = ?");
$stmt->execute([$_GET['user']]);
```

### Audit logging

Tous les changements sont enregistrés:

```sql
SELECT * FROM admin_audit WHERE action = 'delete_user';
```

## 3. Système d'exploitation

### Firewall (UFW)

```bash
# Ports autorisés
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 1812/udp  # RADIUS
ufw allow 1813/udp  # RADIUS Accounting
ufw allow 514/udp   # Syslog
ufw allow 5601/tcp  # Wazuh Dashboard

# Tout le reste est refusé par défaut
ufw default deny incoming
```

### SSH

```bash
# Clés SSH (pas de password)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Configuration sécurisée
sudo nano /etc/ssh/sshd_config
```

Configuration `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30s
```

### Services minimalistes

```bash
# Désactiver les services inutiles
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon

# Services essentiels seulement
sudo systemctl enable freeradius
sudo systemctl enable mariadb
sudo systemctl enable nginx
sudo systemctl enable wazuh-manager
sudo systemctl enable wazuh-agent
```

### Audit

```bash
# Vérifier les changements
sudo auditctl -l

# Voir les logs d'audit
sudo ausearch -k sae501_changes
```

## 4. Application web (PHP)

### Authentification

```php
// Stockage sécurisé des identifiants
require_once '/opt/sae501/secrets/db.env';
// JAMAIS dans le code!
```

### CSRF Protection

```php
// Générer un token
$_SESSION['csrf_token'] = bin2hex(random_bytes(32));

// Vérifier le token
if ($_POST['csrf_token'] !== $_SESSION['csrf_token']) {
    die('CSRF attack prevented');
}
```

### Rate Limiting

```php
// 10 tentatives par minute par utilisateur
if (!check_rate_limit($username)) {
    http_response_code(429); // Too Many Requests
    die('Trop de tentatives');
}
```

### Validation input

```php
// Valider le nom d'utilisateur
if (!preg_match('/^[a-zA-Z0-9._-]{3,64}$/', $username)) {
    throw new Exception('Invalid username format');
}

// Valider le mot de passe (8 chars min, majuscule, chiffre, spécial)
if (!preg_match('/^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*]).{8,}$/', $password)) {
    throw new Exception('Weak password');
}
```

### Sessions sécurisées

```php
ini_set('session.http_only', 1);        // Pas d'accès JavaScript
ini_set('session.secure', 1);           // HTTPS seulement
ini_set('session.same_site', 'Strict'); // Pas de cross-site
ini_set('session.cookie_lifetime', 0);  // Session cookie
```

## 5. Chiffrement et certificats

### HTTPS/TLS

```bash
# Générer un certificat self-signed
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/server.key \
  -out /etc/ssl/certs/server.crt

# Permissions
chown root:root /etc/ssl/private/server.key
chmod 600 /etc/ssl/private/server.key
```

### Certificat RADIUS

```bash
# Vérifier l'expiration
openssl x509 -in /etc/radius/certs/server.crt -noout -enddate

# Renouveler avant l'expiration
sudo -u freerad openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout /etc/radius/certs/server.key \
  -out /etc/radius/certs/server.crt
```

## 6. Logging et monitoring

### Centralisation des logs

```bash
# Logs RADIUS
/var/log/sae501/radius/auth.log     # Authentifications
/var/log/sae501/radius/reply.log    # Réponses RADIUS

# Logs admin
/var/log/sae501/php_admin_audit.log # Actions d'administration

# Logs système
journalctl -u freeradius -f
journalctl -u mariadb -f
```

### Analyse avec Wazuh

```bash
# Vérifier les alertes
sudo tail -f /var/ossec/logs/alerts/alerts.log

# Rechercher les tentatives cochées
sudo grep -i "reject\|failure" /var/ossec/logs/alerts/alerts.log
```

## 7. Conformité réglementaire

### RGPD
- ✅ Minimal data collection
- ✅ Audit logging de tous les accès
- ✅ Chiffrement des données sensibles
- ✅ Droits d'accès stricts
- ✅ Retention policy (30 jours de logs)

### ANSSI
- ✅ Authentification forte (PEAP)
- ✅ Separation des comptes
- ✅ Monitoring centralisé
- ✅ Firewall configuré
- ✅ Audit trail complet

## 8. Procédures de sécurité

### Changement de mot de passe admin

```bash
# Générer un nouveau hash
php -r "echo password_hash('NewPassword@2024', PASSWORD_BCRYPT) . PHP_EOL;"

# Mettre à jour
sudo mysql radius -u root
UPDATE admin_users SET password_hash = '...' WHERE username = 'admin';
```

### Rotation des clés RADIUS

```bash
# Générer une nouvelle clé secrète
openssl rand -base64 32 | tr -d "=+/" | cut -c1-25

# Mettre à jour dans /etc/freeradius/3.0/clients.conf
# Redémarrer FreeRADIUS
```

### Backup sécurisé

```bash
# Backup chiffré de la DB
mysqldump -u root radius | openssl enc -aes-256-cbc -out backup.sql.enc

# Restore
openssl enc -d -aes-256-cbc -in backup.sql.enc | mysql -u root radius
```

## 9. Incident response

### Tentatives d'intrusion détectées

```bash
# Chercher les logs suspectes
sudo grep -i "multiple.*reject\|brute" /var/ossec/logs/alerts/alerts.log

# Bloquer l'adresse IP
sudo ufw deny from 192.168.1.100

# Analyser les logs d'audit
sudo mysql radius -u radiususer -p
SELECT * FROM admin_audit WHERE ip_address = '192.168.1.100';
```

## 10. Checklist sécurité mensuelle

- [ ] Vérifier les certificats (expiration)
- [ ] Rot ation des clés RADIUS
- [ ] Audit des utilisateurs actifs
- [ ] Logs d'accès anormaux
- [ ] Patch du système
- [ ] Backup de la DB
- [ ] Test de restore du backup
- [ ] Scan des vulnérébilités

---

**Dernière mise à jour**: 23 janvier 2026
**Version**: 1.0.0

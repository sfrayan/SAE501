# Guide d'Installation SAE501

## 🚀 Démarrage Rapide

### Prérequis

- **OS:** Ubuntu 20.04+, Debian 11+, ou Rocky Linux 8+
- **Accès root:** Vous devez avoir accès à `sudo`
- **Ressources minimum:**
  - CPU: 2 cores
  - RAM: 2 GB
  - Disque: 10 GB libres
- **Réseau:** Connexion Internet pour télécharger les packages

### Installation Complète (Recommandée)

Lancez le script maître d'installation qui automatise tout:

```bash
sudo bash scripts/install_all.sh
```

**C'est tout!** Le script va:
1. ✓ Installer MySQL/MariaDB
2. ✓ Configurer FreeRADIUS avec support 802.1X/PEAP
3. ✓ Déployer l'interface web PHP-Admin
4. ✓ Appliquer le hardening de sécurité
5. ✓ Générer les certificats SSL/TLS
6. ✓ Setup Wazuh pour le monitoring

**Durée:** ~10-15 minutes selon votre connexion Internet

---

## 📊 Qu'est-ce qui s'installe?

### 1. Base de Données (MySQL/MariaDB)
- Base `radius` avec schéma complet FreeRADIUS
- Utilisateur `radiususer` avec permissions appropriées
- Tables pour l'authentification, les groupes, les NAS, l'accounting

### 2. Serveur RADIUS (FreeRADIUS 3.x)
- Authentification sur port 1812/UDP
- Accounting sur port 1813/UDP
- Intégration MySQL
- Support 802.1X/PEAP/EAP-TLS
- Clients RADIUS configurés (localhost, 127.0.0.1)

### 3. Interface Admin (PHP-Admin)
- Web UI sur http://localhost/php-admin/
- Gestion des utilisateurs RADIUS
- Dashboard avec statistiques
- Logs d'audit
- Authentification sécurisée

### 4. Sécurité (Hardening)
- Firewall UFW configuré
- SSH durci (clés SSH recommandées)
- Kernel security parameters
- Fail2Ban pour brute-force protection
- Audit daemon pour logging
- Permissions fichiers sécurisées

### 5. Certificats SSL/TLS
- Certificats auto-signés pour HTTPS
- Compatibles avec EAP-TLS
- Location: `/etc/ssl/certs/` et `/etc/ssl/private/`

### 6. Monitoring (Optionnel)
- Wazuh Manager (peut échouer en environnement isolé)
- Elasticsearch pour stockage des logs
- Kibana pour visualisation

---

## 🔑 Identifiants par Défaut

⚠️ **À CHANGER IMMÉDIATEMENT APRÈS L'INSTALLATION**

### PHP-Admin (Interface Web)
```
URL: http://localhost/php-admin/
Utilisateur: admin
Mot de passe: Admin@Secure123!
```

### RADIUS (Authentification)
```
Serveur: localhost
Port Auth: 1812/UDP
Port Accounting: 1813/UDP
Secret (localhost): testing123
```

### MySQL (Base de données)
```
Hôte: localhost
Port: 3306
Utilisateur: radiususer
Base: radius
Mot de passe: (généré automatiquement, dans db.env)
```

---

## ✅ Vérification Après Installation

### 1. Vérifier que tout fonctionne

```bash
bash scripts/diagnostics.sh
```

Cela affichera:
- ✓ État des services
- ✓ Ports en écoute
- ✓ Connectivité base de données
- ✓ Accès PHP-Admin
- ✓ État FreeRADIUS

### 2. Afficher les identifiants

```bash
bash scripts/show_credentials.sh
```

Affiche:
- Statut des services
- Tous les identifiants
- URLs d'accès
- Commandes de diagnostic
- Recommandations de sécurité

### 3. Accéder à l'interface admin

1. Ouvrez votre navigateur: http://localhost/php-admin/
2. Connectez-vous: `admin` / `Admin@Secure123!`
3. **Changez le mot de passe immédiatement**
4. Gérez les utilisateurs RADIUS

### 4. Tester RADIUS

```bash
# Installer l'outil de test (si pas déjà fait)
sudo apt-get install freeradius-utils

# Tester avec un utilisateur par défaut
radtest admin Admin@Secure123! localhost 0 testing123

# Résultat attendu:
# Sending Access-Request of id... to 127.0.0.1:1812
# ...
# rad_recv: Access-Accept packet...
```

---

## 🔐 Sécurité

### Avant d'utiliser en Production

1. **✓ Changez TOUS les mots de passe par défaut**
   ```bash
   # Accédez à PHP-Admin et changez le mot de passe admin
   # Changez les mots de passe MySQL
   # Changez le secret RADIUS
   ```

2. **✓ Configurez HTTPS**
   ```bash
   # Les certificats self-signed sont générés
   # Pour production, obtenez une cert signée par une CA
   # Configurez Apache pour HTTPS
   ```

3. **✓ Configurez le Firewall**
   ```bash
   # UFW est déjà activé avec les ports essentiels
   # Vérifiez les règles:
   sudo ufw status verbose
   
   # Ajustez pour votre réseau si nécessaire
   ```

4. **✓ Activez Key-Based SSH**
   ```bash
   # Générez une clé SSH
   ssh-keygen -t ed25519
   
   # Copiez sur le serveur
   ssh-copy-id user@serveur
   
   # Désactivez password auth après
   # Éditez /etc/ssh/sshd_config:
   # PasswordAuthentication no
   ```

5. **✓ Configurez les sauvegardes**
   ```bash
   # Sauvegarde base RADIUS
   mysqldump -u radiususer -p radius > /backup/radius-$(date +%Y%m%d).sql
   ```

6. **✓ Mettez à jour les packages**
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

7. **✓ Activez l'audit**
   ```bash
   # Auditd est déjà configuré
   # Vérifiez les règles:
   sudo auditctl -l
   
   # Consultez les logs:
   sudo tail -f /var/log/audit/audit.log
   ```

---

## 📋 Options d'Installation

### Installation Complète (Par défaut)
```bash
sudo bash scripts/install_all.sh
```
Tout en automatique.

### Installation Personnalisée

Si vous préférez installer composant par composant:

```bash
# 1. DATABASE (REQUIS EN PREMIER)
sudo bash scripts/install_mysql.sh

# Attend 30 secondes pour que MySQL démarre
sleep 30

# 2. RADIUS SERVER
sudo bash scripts/install_radius.sh

# 3. WEB INTERFACE
sudo bash scripts/install_php_admin.sh

# 4. SECURITY HARDENING
sudo bash scripts/install_hardening.sh

# 5. SSL/TLS CERTIFICATES
sudo bash scripts/generate_certificates.sh

# 6. MONITORING (OPTIONAL - peut échouer)
sudo bash scripts/install_wazuh.sh || echo "Wazuh skipped"
```

---

## 🐛 Dépannage

### MySQL ne démarre pas

```bash
# Vérifier l'état
sudo systemctl status mysql

# Voir les erreurs
sudo journalctl -xe

# Consulter les logs
sudo tail -100 /var/log/mysql/error.log

# Redémarrer
sudo systemctl restart mysql
```

### FreeRADIUS ne démarre pas

```bash
# Tester la configuration
sudo freeradius -X -d /etc/freeradius/

# Voir l'état
sudo systemctl status freeradius

# Consulter les logs
sudo tail -f /var/log/freeradius/radius.log
```

### PHP-Admin non accessible

```bash
# Vérifier Apache
sudo systemctl status apache2

# Vérifier PHP
php -v
php -m | grep mysql

# Tester la connexion
curl -I http://localhost/php-admin/

# Vérifier les permissions
ls -la /var/www/html/php-admin/
```

### SSH verrouillé (Firewall UFW)

Si vous avez accès root mais pas SSH:

```bash
# Désactiver UFW temporairement
sudo ufw disable

# Vérifier/réparer les règles
sudo ufw status verbose

# Réactiver
sudo ufw enable
```

### Radtest échoue

```bash
# Tester avec les identifiants par défaut
radtest admin Admin@Secure123! localhost 0 testing123

# Résultat attendu: "Received reply code from server"

# Vérifier que RADIUS écoute
sudo netstat -ulpn | grep radius

# Consulter les logs RADIUS
sudo tail -f /var/log/freeradius/radius.log
```

---

## 📂 Fichiers Importants

### Configuration
```
/etc/freeradius/              - Configuration RADIUS
/etc/mysql/                   - Configuration MySQL
/etc/apache2/                 - Configuration Apache
/etc/ssh/sshd_config          - Configuration SSH (durcie)
/etc/ssl/certs/               - Certificats
/etc/ssl/private/             - Clés privées
```

### Données
```
/var/lib/freeradius/          - Données FreeRADIUS
/var/lib/mysql/               - Données MySQL
/var/www/html/php-admin/      - Interface Admin
/opt/sae501/secrets/          - Identifiants (db.env)
```

### Logs
```
/var/log/sae501/              - Logs d'installation
/var/log/freeradius/          - Logs RADIUS
/var/log/mysql/               - Logs MySQL
/var/log/apache2/             - Logs Apache
/var/log/auth.log             - Logs authentification
/var/log/audit/audit.log      - Logs audit
```

---

## 📞 Support & Documentation

- **Installation détaillée:** `scripts/README.md`
- **Architecture:** `docs/architecture.md`
- **Hardening Linux:** `docs/hardening-linux.md`
- **Journal du projet:** `docs/journal-de-bord.md`
- **README complet:** `README.md`

---

## ✨ Prochaines Étapes

1. ✅ Installation complète (`install_all.sh`)
2. ✅ Vérification (`diagnostics.sh`)
3. ✅ Afficher les identifiants (`show_credentials.sh`)
4. ✅ Accéder à PHP-Admin et changer les mots de passe
5. ✅ Configurer les utilisateurs RADIUS
6. ✅ Tester l'authentification RADIUS
7. ✅ Configurer les routeurs WiFi
8. ✅ Activer le monitoring Wazuh
9. ✅ Configurer les sauvegardes
10. ✅ Lire la documentation complète

---

## 📌 Notes Importantes

- **Droits root:** Tous les scripts requièrent `sudo`
- **Logs:** Tout est logué dans `/var/log/sae501/`
- **Durée:** ~10-15 minutes pour installation complète
- **Idempotent:** Les scripts peuvent être relancés sans danger
- **Backups:** Les configs existantes sont sauvegardées avec `.bak`
- **Wazuh:** Optionnel et peut échouer en environnement isolé

---

**Version:** 1.0  
**Date:** 2026-01-25  
**Status:** Production Ready  
**Auteur:** SAE501 Security Team

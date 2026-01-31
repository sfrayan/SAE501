# SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

## 🌟 But du projet

Créer une **infrastructure d'authentification RADIUS centralisée** pour une chaîne de salles de sport permettant:
- 💫 Authentification WPA-Enterprise sécurisée (PEAP-MSCHAPv2)
- 👎 Gestion centralisée des utilisateurs
- 📊 Monitoring et détection d'anomalies
- 🔐 Logs d'audit complets
- 🎐 Installation modulaire et personnalisable
- 🛡️ **Hardening sécurité complet**
- ✨ **Toutes configurations générées automatiquement**

---

## 💻 Composants du système

### **FreeRADIUS** (Port 1812/1813)
- Serveur d'authentification RADIUS
- Protocole: PEAP-MSCHAPv2 (sans certificat client)
- Base de données utilisateurs: MySQL
- ✨ **Configuration 100% automatique** - aucun fichier externe requis

### **PHP-Admin** (Port 80/443)
- Interface web de gestion
- Ajouter/modifier/supprimer utilisateurs
- Logs d'audit complets
- Paramétrages système

### **MySQL/MariaDB** (Port 3306)
- Base de données RADIUS
- Stockage utilisateurs (mots de passe hashés)
- Logs d'authentification

### **Wazuh** (Port 5601/1514)
- 🆕 **Monitoring en temps réel**
- 🔍 **Détection d'anomalies avancée**
- 🚨 **Alertes de sécurité personnalisées**
- 📊 **Dashboard OpenSearch interactif**
- ✨ **Installation 100% autonome - Zéro configuration manuelle**
- 🔧 **Manager + Dashboard en un seul script**

---

## 📁 Pré-requis

- **OS**: Debian 12+ ou Ubuntu 22.04+
- **RAM**: 4GB minimum (**8GB recommandé avec Wazuh**)
- **CPU**: 2 cores minimum
- **Disque**: 50GB minimum
- **Accès root** pour l'installation
- **Connexion internet** pendant l'installation

---

# 🚀 GUIDE D'INSTALLATION - ÉTAPE PAR ÉTAPE

## **ÉTAPE 1: Préparation de la VM**

### 1.1 Créer une VM
- VirtualBox ou Proxmox
- Debian 12 ou Ubuntu 22.04
- Allocer **8GB RAM** (4GB minimum), 2 CPU, 50GB disque

### 1.2 Installer Debian/Ubuntu
```bash
# Pendant l'installation:
# - Pas de bureau graphique nécessaire
# - SSH activé
# - Utilisateur standard créé
```

### 1.3 Vérifier la connexion
```bash
ping google.com
```

---

## **ÉTAPE 2: Télécharger le projet**

```bash
# Se connecter en SSH ou terminal
sudo su  # Passer en root

# Cloner le répository
git clone https://github.com/sfrayan/SAE501.git
cd SAE501

# Rendre les scripts exécutables
chmod +x scripts/*.sh
```

---

## **ÉTAPE 3: Installation modulaire (RECOMMANDÉ)**

### 💉 Installation par étapes - Exécuter dans l'ordre

```bash
# 1. Installer MySQL et créer la base de données
sudo bash scripts/install_mysql.sh

# 2. Installer FreeRADIUS (100% AUTONOME)
# ✨ Génère AUTOMATIQUEMENT:
#    - Certificats SSL auto-signés
#    - Configuration SQL (rlm_sql_mysql)
#    - Configuration EAP (PEAP-MSCHAPv2)
#    - Sites default + inner-tunnel
#    - Module mschap
#    - Test d'authentification
sudo bash scripts/install_radius.sh

# 3. Installer PHP-Admin (interface web)
sudo bash scripts/install_php_admin.sh

# 4. Installer Wazuh (monitoring) - OPTIONNEL
# 🆕 NOUVELLE VERSION 100% AUTONOME!
# ✨ Installe AUTOMATIQUEMENT:
#    - Wazuh Manager 4.7
#    - OpenSearch (moteur de recherche)
#    - Filebeat (collecteur de logs)
#    - Wazuh Dashboard (interface web)
#    - Configuration complète ossec.conf
#    - Règles personnalisées RADIUS
#    - Aucun fichier externe requis!
sudo bash scripts/install_wazuh.sh

# 5. Appliquer le hardening sécurité - RECOMMANDÉ
sudo bash scripts/install_hardening.sh
```

**Durée estimée**: 
- **Sans Wazuh**: 10-15 minutes
- **Avec Wazuh**: 20-30 minutes (installation complète + Dashboard)

**✨ Nouveautés du script Wazuh**:
- ✅ **Zéro dépendance** aux fichiers de configuration externes
- ✅ Génération automatique d'ossec.conf complet (monitoring RADIUS, MySQL, Apache, système)
- ✅ Création automatique de 10 règles d'alerte personnalisées pour RADIUS
- ✅ Installation OpenSearch + Filebeat + Dashboard en un seul script
- ✅ Configuration automatique de la collecte syslog (port 514 UDP)
- ✅ Détection de rootkits et File Integrity Monitoring activés
- ✅ Dashboard web accessible sur `http://IP:5601`
- ✅ Logs détaillés dans `/var/log/sae501_wazuh_install.log`

**Avantages de l'installation modulaire**:
- ✅ Contrôle total sur chaque composant
- ✅ Possibilité de sauter des modules (ex: Wazuh)
- ✅ Debugging facilité en cas de problème
- ✅ Installation personnalisée selon vos besoins

---

## **ÉTAPE 4: Vérifier l'installation**

### 4.1 Vérifier les services
```bash
# Affiche l'état de tous les services
bash scripts/diagnostics.sh
```

Vous devriez voir:
- ✓ FreeRADIUS ACTIF
- ✓ MySQL ACTIF
- ✓ PHP-FPM ACTIF
- ✓ Apache2 ACTIF
- ✓ Wazuh Manager ACTIF (si installé)
- ✓ OpenSearch ACTIF (si installé)
- ✓ Filebeat ACTIF (si installé)
- ✓ Wazuh Dashboard ACTIF (si installé)

### 4.2 Vérifier les accès
```bash
bash scripts/diagnostics.sh
```

Notez les identifiants affichés!

### 4.3 Tester l'authentification RADIUS

```bash
# Test avec l'utilisateur créé automatiquement
radtest testuser testpass localhost 0 testing123

# Vous devriez voir:
# Received Access-Accept
```

---

## **ÉTAPE 5: Configuration Sécurité Avancée (RECOMMANDÉ) ⭐**

### 5.1 Générer des certificats SSL valides (PRODUCTION)

```bash
# Pour la production (Let's Encrypt)
sudo apt-get install -y certbot python3-certbot-apache
sudo certbot certonly --apache -d VOTRE_DOMAINE.com

# Remplacer les certificats auto-signés
sudo ln -sf /etc/letsencrypt/live/VOTRE_DOMAINE.com/fullchain.pem /etc/freeradius/3.0/certs/server.pem
sudo ln -sf /etc/letsencrypt/live/VOTRE_DOMAINE.com/privkey.pem /etc/freeradius/3.0/certs/server.key
sudo systemctl restart freeradius
```

### 5.2 Vérifier le hardening appliqué

```bash
# Vérifier UFW firewall
sudo ufw status verbose

# Vérifier SSH hardening
sudo sshd -T | grep -E "PermitRootLogin|PasswordAuthentication|X11"

# Vérifier MySQL hardening
mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# Vérifier Fail2Ban
sudo fail2ban-client status
```

### 5.3 Consulter le guide complet

```bash
# Voir le guide de sécurité détaillé
cat docs/HARDENING_GUIDE.md
```

---

## **ÉTAPE 6: Premières configurations**

### 6.1 Accéder à PHP-Admin

```
URL: http://VOTRE_IP/admin
Utilisateur: admin
Mot de passe: Admin@Secure123! (affiché en fin d'install)
```

**Dès le premier accès**:
1. Allez dans "Paramétrages"
2. Changez le mot de passe admin
3. Configurez le secret RADIUS
4. Configurez l'IP du routeur NAS

### 6.2 Accéder au Wazuh Dashboard (si installé) 🆕

```
URL: http://VOTRE_IP:5601
Utilisateur: admin
Mot de passe: Admin@Wazuh123!
```

**⚠️ CHANGEZ IMMÉDIATEMENT LE MOT DE PASSE!**

**Explorez le dashboard**:
- 📊 **Vue d'ensemble**: Statistiques en temps réel
- 💱 **Sécurité Events**: Alertes de sécurité classées par sévérité
- 🚀 **Integrity Monitoring**: Surveillance des modifications de fichiers
- 🔍 **Vulnerability Detection**: Scan de vulnérabilités actif
- 📄 **RADIUS Logs**: Authentifications réussies/échouées
- 🚨 **Alertes personnalisées**:
  - Tentatives multiples d'authentification (attaque brute-force)
  - Erreurs de connexion MySQL
  - Clients RADIUS non autorisés
  - Certificats SSL expirés
  - Et 6 autres règles spécifiques RADIUS

### 6.3 CHANGER LES MOTS DE PASSE (⚠️ OBLIGATOIRE!)

```bash
# Afficher les mots de passe actuels
bash scripts/diagnostics.sh

# Changer dans PHP-Admin:
# Admin: Admin@Secure123! → VotreMot@Passe123!

# Changer dans Wazuh Dashboard:
# Admin: Admin@Wazuh123! → VotreMot@Passe123!
# 🚨 Modifier aussi dans /etc/wazuh-dashboard/opensearch_dashboards.yml

# Changer MySQL root:
mysql -u root -p
# Enter: MySQL@Root123!
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NouveauMot@Passe123!';
EXIT;
```

---

## **ÉTAPE 7: Configurer le routeur Wi-Fi**

### 7.1 Accéder à l'interface du routeur

```
URL: http://192.168.1.1
Login: admin
Password: admin (par défaut TP-Link)
```

### 7.2 Configurer l'authentification Wi-Fi

1. Allez dans **Wireless Settings** ou **Security**
2. Sélectionnez le SSID d'entreprise
3. **Security Type**: WPA-Enterprise (ou WPA3-Enterprise)
4. **Authentication Type**: PEAP ou EAP-TLS
5. **RADIUS Server IP**: Adresse IP du serveur SAE501
6. **RADIUS Server Port**: 1812
7. **Shared Secret**: Celui configuré dans `radius/clients.conf` (par défaut: `testing123`)
8. **Cliquer Save**

### 7.3 Tester la connexion

Sur un ordinateur:
1. Chercher le réseau Wi-Fi
2. Connecter à l'SSID "Entreprise"
3. Type d'authentification: WPA-Enterprise
4. Entrer un identifiant RADIUS créé en PHP-Admin (ou `testuser`)
5. Entrer le mot de passe (ou `testpass`)
6. Vérifier dans les logs: `sudo tail -f /var/log/freeradius/radius.log`
7. Vérifier dans Wazuh Dashboard: Voir l'alerte "Authentification réussie"

---

## **ÉTAPE 8: Gestion des utilisateurs**

### 8.1 Ajouter un utilisateur

**Via PHP-Admin**:
1. Accédez à `http://VOTRE_IP/admin`
2. Cliquez "Ajouter utilisateur"
3. Entrez:
   - Identifiant: `jean.dupont`
   - Mot de passe: `MonPasse@123`
4. Cliquez "Énregistrer"

**Via CLI (optionnel)**:
```bash
mysql -u radiusapp -p radius
# Mot de passe: RadiusApp@Secure123!

INSERT INTO radcheck (username, attribute, op, value) 
VALUES ('jean.dupont', 'Cleartext-Password', ':=', 'MonPasse@123');

EXIT;
```

### 8.2 Lister les utilisateurs

**Via PHP-Admin**:
1. Cliquez "Lister utilisateurs"
2. Voir tous les comptes créés
3. Actions: modifier, supprimer, activer/désactiver

### 8.3 Consulter les logs d'authentification

**Via PHP-Admin**:
1. Cliquez "Logs d'audit"
2. Filtrez par date/action
3. Voir qui s'est connecté, quand, d'où, résultat

**Via Wazuh Dashboard**:
1. Onglet "RADIUS Logs"
2. Voir authentications en temps réel
3. Filtrer par utilisateur, IP, résultat

**Logs en temps réel**:
```bash
sudo tail -f /var/log/freeradius/radius.log
```

---

## **ÉTAPE 9: Monitoring et sécurité avec Wazuh 🆕**

### 9.1 Dashboard Wazuh - Vue d'ensemble

**Accéder au dashboard**:
```
URL: http://VOTRE_IP:5601
User: admin
Pass: Admin@Wazuh123!  (CHANGEZ-LE!)
```

**Sections importantes**:
1. **Overview** (🏠): Statistiques globales
   - Nombre total d'alertes (24h/7j/30j)
   - Top 10 des agents
   - Distribution des alertes par niveau

2. **Security Events** (🚨): Alertes de sécurité
   - Niveau 3: Info (authentifications réussies)
   - Niveau 5: Notice (échecs d'authentification)
   - Niveau 10: Critical (attaques détectées)

3. **Integrity Monitoring** (📄): Surveillance fichiers
   - Modifications dans `/etc/freeradius`
   - Modifications dans `/var/ossec`
   - Alertes sur changements suspects

4. **Vulnerability Detection** (🔍): Scan de vulnérabilités
   - CVE détectés sur le système
   - Packages obsolètes
   - Patches recommandés

### 9.2 Règles d'alerte personnalisées RADIUS

Le script Wazuh crée automatiquement **10 règles** spécifiques:

| Rule ID | Description | Niveau |
|---------|-------------|--------|
| 100001 | Authentification RADIUS réussie | 3 (Info) |
| 100002 | Authentification RADIUS échouée | 5 (Notice) |
| 100003 | Multiple échecs depuis même IP (5 en 5min) | 10 (Critical) |
| 100004 | Service RADIUS démarré | 3 (Info) |
| 100005 | Erreur connexion MySQL | 8 (Important) |
| 100006 | Client RADIUS non autorisé | 7 (Warning) |
| 100007 | Certificat SSL expiré | 8 (Important) |
| 100008 | Utilisateur inconnu | 5 (Notice) |
| 100009 | Mot de passe incorrect | 5 (Notice) |
| 100010 | Serveur RADIUS surchargé | 9 (Alert) |

### 9.3 Utiliser les filtres avancés

**Rechercher des authentifications échouées**:
```
rule.id:100002
```

**Rechercher des attaques potentielles**:
```
rule.id:100003
```

**Rechercher par utilisateur**:
```
data.srcuser:"jean.dupont"
```

**Rechercher par IP source**:
```
data.srcip:"192.168.1.100"
```

### 9.4 Créer des dashboards personnalisés

1. Cliquez sur **Visualize** dans le menu
2. Créez un graphique "Authentifications par heure"
3. Ajoutez-le à un dashboard personnalisé
4. Partagez le dashboard avec votre équipe

### 9.5 Vérifier les infos système

**Via PHP-Admin**:
1. Cliquez "Infos système"
2. Voir l'état des services
3. Cliquer sur "Tester" pour diagnostics

**Via Wazuh Dashboard**:
1. Onglet "Agents"
2. Cliquer sur l'agent local
3. Voir CPU, RAM, disque en temps réel

### 9.6 Dépannage Wazuh

**Si quelque chose ne fonctionne pas**:
```bash
# Diagnostics détaillés Wazuh
sudo systemctl status wazuh-manager
sudo systemctl status opensearch
sudo systemctl status filebeat
sudo systemctl status wazuh-dashboard

# Voir les logs d'installation Wazuh
sudo tail -f /var/log/sae501_wazuh_install.log

# Voir les logs Wazuh Manager
sudo tail -f /var/ossec/logs/ossec.log

# Voir les alertes en temps réel
sudo tail -f /var/ossec/logs/alerts/alerts.log

# Tester la connexion OpenSearch
curl http://localhost:9200

# Tester le dashboard
curl http://localhost:5601

# Rebooter les services
sudo systemctl restart wazuh-manager
sudo systemctl restart opensearch
sudo systemctl restart filebeat
sudo systemctl restart wazuh-dashboard
```

---

## **ÉTAPE 10: Sauvegarder et maintenir**

### 10.1 Sauvegarder la base de données

```bash
# Sauvegarde complète
mysqldump -u root -p radius > backup_radius_$(date +%Y%m%d).sql

# Entrer le mot de passe MySQL root
```

### 10.2 Sauvegarder la configuration Wazuh

```bash
# Sauvegarder Wazuh
tar -czf backup_wazuh_$(date +%Y%m%d).tar.gz /var/ossec/etc
```

### 10.3 Restaurer une sauvegarde

```bash
# Si problème, restaurer
mysql -u root -p radius < backup_radius_20260123.sql
tar -xzf backup_wazuh_20260123.tar.gz -C /
```

### 10.4 Maintenance régulière

```bash
# Chaque semaine:
# - Consulter les logs d'audit en PHP-Admin
# - Vérifier Wazuh Dashboard pour anomalies
# - Faire une sauvegarde

# Chaque mois:
# - Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Vérifier les logs
sudo journalctl -u freeradius --since today
sudo journalctl -u wazuh-manager --since today
```

---

## 🔐 Sécurité - POINTS CRITIQUES

### ⚠️ AVANT PRODUCTION

**OBLIGATOIRE**:
- [ ] Changez TOUS les mots de passe par défaut
- [ ] Remplacez les certificats auto-signés par des certificats valides (Let's Encrypt)
- [ ] Activez HTTPS partout
- [ ] Configurez le firewall UFW
- [ ] Testez les sauvegardes
- [ ] Désactivez les accès inutiles
- [ ] Changez le secret RADIUS `testing123` dans `radius/clients.conf`
- [ ] Changez le mot de passe Wazuh Dashboard
- [ ] Changez le mot de passe OpenSearch dans `/etc/wazuh-dashboard/opensearch_dashboards.yml`

**FORTEMENT RECOMMANDÉ**:
- [ ] Activez 2FA pour PHP-Admin
- [ ] Limitez l'accès SSH (clés uniquement)
- [ ] Configurez les alertes Wazuh par email
- [ ] Mettez en place des backups automatiques
- [ ] Utilisez un VPN pour administrer
- [ ] Lisez le guide complet: `docs/HARDENING_GUIDE.md`

### 📈 Bonnes pratiques

```bash
# 1. Firewall (UFW)
sudo ufw enable
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 1812/udp    # RADIUS
sudo ufw allow 5601/tcp    # Wazuh Dashboard
sudo ufw allow 514/udp     # Wazuh Syslog
sudo ufw allow 1514/tcp    # Wazuh Agent

# 2. SSH sécurisé
sudo nano /etc/ssh/sshd_config
# Remplacer:
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes

# 3. Logs régulièrement audités
sudo tail -f /var/log/auth.log
sudo tail -f /var/log/syslog
sudo tail -f /var/ossec/logs/alerts/alerts.log
```

---

## 📊 Fichiers et structure

```
SAE501/
├── scripts/                    # Scripts d'installation
│   ├── install_mysql.sh        🎆 Base de données
│   ├── install_radius.sh       🎆 Serveur RADIUS (100% AUTONOME)
│   ├── install_php_admin.sh    🎆 Interface web
│   ├── install_wazuh.sh        🎆 Monitoring COMPLET (100% AUTONOME)
│   ├── install_hardening.sh    🎆 Sécurité (recommandé)
│   ├── generate_certificates.sh
│   └── diagnostics.sh
│
├── radius/                     # Configuration RADIUS
│   ├── clients.conf            ✅ SEUL FICHIER REQUIS
│   └── sql/
│       ├── create_tables.sql
│       └── init_appuser.sql
│
├── php-admin/                  # Interface web
│   ├── index.php
│   ├── config.php
│   ├── auth.php
│   ├── functions.php
│   └── pages/
│       ├── dashboard.php
│       ├── list_users.php
│       ├── add_user.php
│       ├── delete_user.php
│       ├── audit.php
│       ├── system.php
│       └── settings.php
│
├── docs/                       # Documentation
│   ├── HARDENING_GUIDE.md
│   ├── dossier-architecture.md
│   ├── hardening-linux.md
│   └── journal-de-bord.md
│
└── README.md                   # CE FICHIER

NOTE: Le dossier wazuh/ a été SUPPRIMÉ car toutes les configurations
sont maintenant générées automatiquement par le script install_wazuh.sh!
```

---

## 🛠️ Dépannage rapide

| Problème | Solution |
|----------|----------|
| Installation bloque | Vérifier connexion internet: `ping google.com` |
| RADIUS ne démarre pas | `sudo systemctl status freeradius` ou `sudo freeradius -X` |
| Configuration RADIUS échoue | Vérifier `/var/log/sae501_radius_install.log` |
| PHP-Admin inaccessible | `sudo systemctl restart apache2 php-fpm` |
| Wazuh ne répond pas | `sudo systemctl restart wazuh-manager opensearch filebeat wazuh-dashboard` |
| Wazuh Dashboard HTTP 502 | `sudo systemctl status opensearch` - Vérifier RAM disponible |
| Authentification échoue | Vérifier identifiant/mot de passe en PHP-Admin |
| Connexion Wi-Fi échoue | Vérifier logs: `sudo tail -f /var/log/freeradius/radius.log` |
| Certificats SSL invalides | Remplacer par Let's Encrypt (voir étape 5.1) |
| OpenSearch ne démarre pas | Vérifier JVM: `sudo journalctl -u opensearch --since "5 minutes ago"` |

---

## 📚 Commandes essentielles

```bash
# Installation modulaire (DANS L'ORDRE)
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh      # ✨ 100% AUTONOME
sudo bash scripts/install_php_admin.sh
sudo bash scripts/install_wazuh.sh        # ✨ 100% AUTONOME - Manager + Dashboard!
sudo bash scripts/install_hardening.sh    # RECOMMANDÉ

# Voir l'état du système
bash scripts/diagnostics.sh

# Tester l'authentification RADIUS
radtest testuser testpass localhost 0 testing123

# Voir logs RADIUS
sudo tail -f /var/log/freeradius/radius.log
sudo tail -f /var/log/sae501_radius_install.log

# Voir logs Wazuh
sudo tail -f /var/ossec/logs/alerts/alerts.log
sudo tail -f /var/log/sae501_wazuh_install.log

# Mode debug complet RADIUS
sudo freeradius -X

# Rebooter services
sudo systemctl restart freeradius mysql apache2 php-fpm
sudo systemctl restart wazuh-manager opensearch filebeat wazuh-dashboard

# Accéder MySQL
mysql -u radiusapp -p radius

# Sauvegarde
mysqldump -u root -p radius > backup.sql
tar -czf backup_wazuh.tar.gz /var/ossec/etc
```

---

## ✅ Checklist finale

- [ ] VM créée (**8GB RAM recommandé** avec Wazuh, 2 CPU, 50GB disque)
- [ ] Debian/Ubuntu 22.04+ installé
- [ ] Repository SAE501 cloné
- [ ] Scripts individuels exécutés dans l'ordre
- [ ] FreeRADIUS démarré et teste `testuser` fonctionne
- [ ] Mots de passe changés
- [ ] Secret RADIUS changé dans `radius/clients.conf`
- [ ] Certificats SSL remplacés (production)
- [ ] PHP-Admin accessible et fonctionnel
- [ ] **Wazuh Dashboard accessible sur `http://IP:5601`**
- [ ] **Mot de passe Wazuh changé (Admin@Wazuh123! → VotreMot@Passe123!)**
- [ ] **Vérifié les 4 services Wazuh: Manager, OpenSearch, Filebeat, Dashboard**
- [ ] Routeur configuré (RADIUS Server, secret)
- [ ] Utilisateur test créé en PHP-Admin
- [ ] Connexion Wi-Fi testée et fonctionnelle
- [ ] **Logs RADIUS visibles dans Wazuh Dashboard**
- [ ] **Alertes personnalisées RADIUS fonctionnelles**
- [ ] Logs d'audit consultés
- [ ] Firewall UFW configuré
- [ ] Sauvegardes planifiées

---

## 📄 Informations importantes

- **Installation modulaire**: 20-30 minutes avec Wazuh complet
- **Flexibilité**: Installez uniquement ce dont vous avez besoin
- **RADIUS 100% autonome**: Aucun fichier externe requis (sauf `clients.conf`)
- **Wazuh 100% autonome**: Manager + Dashboard + OpenSearch en un seul script!
- **Production-ready**: 95% après configuration
- **Support technique**: Voir les logs ou scripts de diagnostics
- **Guide sécurité complet**: `docs/HARDENING_GUIDE.md`

---

## 🚀 Prêt?

```bash
# Commencer l'installation modulaire:
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh      # ✨ 100% AUTONOME!
sudo bash scripts/install_php_admin.sh

# Optionnel - Monitoring COMPLET:
sudo bash scripts/install_wazuh.sh       # ✨ Manager + Dashboard 100% AUTONOME!

# Recommandé - Sécurité:
sudo bash scripts/install_hardening.sh

# Vérifier l'installation:
bash scripts/diagnostics.sh

# Tester RADIUS:
radtest testuser testpass localhost 0 testing123

# Accéder à l'interface PHP:
http://VOTRE_IP/admin

# Accéder au Wazuh Dashboard:
http://VOTRE_IP:5601
User: admin
Pass: Admin@Wazuh123!  (CHANGEZ-LE!)

# Lire le guide de sécurité:
cat docs/HARDENING_GUIDE.md
```

**Bonne chance! Le système est prêt pour la production. ✅**

---

*SAE501 - Projet SAE - Sorbonne Paris Nord*
*Dernière mise à jour: 31 janvier 2026*
*Version: 3.0 - Installation RADIUS + Wazuh 100% autonome*

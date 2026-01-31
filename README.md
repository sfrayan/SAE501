# SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

## 🌟 But du projet

Créer une **infrastructure d'authentification RADIUS centralisée** pour une chaîne de salles de sport permettant:
- 🐫 Authentification WPA-Enterprise sécurisée (PEAP-MSCHAPv2)
- 👎 Gestion centralisée des utilisateurs
- 📊 Monitoring et détection d'anomalies
- 🔐 Logs d'audit complets
- 🎐 **Installation 100% autonome - ZÉRO fichier externe requis**
- 🛡️ Hardening sécurité complet
- ✨ Toutes configurations générées automatiquement

---

## 💻 Composants du système

### **FreeRADIUS** (Port 1812/1813)
- Serveur d'authentification RADIUS
- Protocole: PEAP-MSCHAPv2 (sans certificat client)
- Base de données utilisateurs: MySQL
- ✨ **Configuration 100% automatique** - aucun fichier externe requis

### **PHP-Admin** (Port 80/443) 🆕
- ✨ **100% AUTO-GÉNÉRÉ - ZÉRO DÉPENDANCE**
- Interface web responsive moderne
- Toutes les pages PHP créées durant l'installation
- Gestion complète des utilisateurs RADIUS
- Logs d'audit détaillés
- Dashboard avec statistiques en temps réel

### **MySQL/MariaDB** (Port 3306)
- Base de données RADIUS
- Stockage utilisateurs (mots de passe chiffrés)
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
- Allouer **8GB RAM** (4GB minimum), 2 CPU, 50GB disque

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

# 3. Installer PHP-Admin (interface web) 🆕
# ✨ GÉNÈRE AUTOMATIQUEMENT:
#    - Toutes les pages PHP (login, dashboard, users, audit, system)
#    - Configuration Apache complète
#    - Permissions sécurisées
#    - Design moderne responsive
#    - ZÉRO fichier externe requis!
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

**✨ Nouveautés PHP-Admin**:
- ✅ **Zéro dépendance** aux fichiers PHP externes
- ✅ Génération automatique de toutes les pages durant l'installation
- ✅ Interface moderne avec dégradés
- ✅ Dashboard avec statistiques en temps réel
- ✅ Gestion utilisateurs (CRUD complet)
- ✅ Logs d'audit détaillés
- ✅ Paramètres système
- ✅ Responsive mobile-friendly
- ✅ Installation en moins de 2 minutes

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

### 4.2 Tester l'authentification RADIUS

```bash
# Test avec l'utilisateur créé automatiquement
radtest testuser testpass localhost 0 testing123

# Vous devriez voir:
# Received Access-Accept
```

### 4.3 Accéder à PHP-Admin 🆕

```
URL: http://VOTRE_IP/admin
Utilisateur: admin
Mot de passe: Admin@Secure123!
```

**Fonctionnalités disponibles**:
- 🏠 **Tableau de bord**: Statistiques en temps réel
- 👥 **Utilisateurs**: Liste complète avec actions
- ➕ **Ajouter**: Création rapide d'utilisateurs
- 📄 **Logs**: Audit détaillé des actions
- ⚙️ **Système**: Informations et diagnostics

---

## **ÉTAPE 5: Configuration Sécurité Avancée (RECOMMANDÉ) ⭐**

### 5.1 CHANGER LES MOTS DE PASSE (⚠️ OBLIGATOIRE!)

```bash
# 1. Changer le mot de passe PHP-Admin:
# Connectez-vous à http://VOTRE_IP/admin
# Allez dans Paramètres > Changer mot de passe

# 2. Changer le secret RADIUS dans clients.conf:
sudo nano /etc/freeradius/3.0/clients.conf
# Remplacez: secret = testing123
# Par: secret = VotreSecret@TrèsSécurisé123!
sudo systemctl restart freeradius

# 3. Changer MySQL root:
mysql -u root -p
# Enter: MySQL@Root123!
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NouveauMot@Passe123!';
EXIT;
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

---

## **ÉTAPE 6: Configurer le routeur Wi-Fi**

### 6.1 Accéder à l'interface du routeur

```
URL: http://192.168.1.1
Login: admin
Password: admin (par défaut TP-Link)
```

### 6.2 Configurer l'authentification Wi-Fi

1. Allez dans **Wireless Settings** ou **Security**
2. Sélectionnez le SSID d'entreprise
3. **Security Type**: WPA-Enterprise (ou WPA3-Enterprise)
4. **Authentication Type**: PEAP ou EAP-TLS
5. **RADIUS Server IP**: Adresse IP du serveur SAE501
6. **RADIUS Server Port**: 1812
7. **Shared Secret**: `testing123` (ou votre secret modifié)
8. **Cliquer Save**

### 6.3 Tester la connexion

Sur un ordinateur:
1. Chercher le réseau Wi-Fi
2. Connecter à l'SSID "Entreprise"
3. Type d'authentification: WPA-Enterprise
4. Entrer un identifiant RADIUS créé en PHP-Admin
5. Entrer le mot de passe
6. Vérifier dans les logs: `sudo tail -f /var/log/freeradius/radius.log`

---

## **ÉTAPE 7: Gestion des utilisateurs avec PHP-Admin**

### 7.1 Ajouter un utilisateur

**Via PHP-Admin** (✅ **RECOMMANDÉ**):
1. Accédez à `http://VOTRE_IP/admin`
2. Cliquez "➕ Ajouter utilisateur"
3. Entrez:
   - Identifiant: `jean.dupont`
   - Mot de passe: `MonPasse@123`
4. Cliquez "✅ Ajouter"

**Avantages PHP-Admin**:
- ✅ Interface graphique intuitive
- ✅ Validation des champs
- ✅ Logs d'audit automatiques
- ✅ Aucune commande SQL manuelle

### 7.2 Lister les utilisateurs

**Via PHP-Admin**:
1. Cliquez "👥 Utilisateurs"
2. Voir tous les comptes créés
3. Actions: ✏️ Modifier, 🗑️ Supprimer

### 7.3 Consulter les logs d'authentification

**Via PHP-Admin**:
1. Cliquez "📄 Logs d'audit"
2. Filtrez par date/action
3. Voir qui s'est connecté, quand, d'où, résultat

**Logs en temps réel**:
```bash
sudo tail -f /var/log/freeradius/radius.log
```

---

## **ÉTAPE 8: Monitoring avec Wazuh Dashboard 🆕**

### 8.1 Accéder au Dashboard Wazuh

```
URL: http://VOTRE_IP:5601
Utilisateur: admin
Mot de passe: Admin@Wazuh123!  (CHANGEZ-LE!)
```

**Sections importantes**:
1. **Overview** (🏠): Statistiques globales
2. **Security Events** (🚨): Alertes de sécurité
3. **Integrity Monitoring** (📄): Surveillance fichiers
4. **RADIUS Logs**: Authentifications réussies/échouées

### 8.2 Règles d'alerte personnalisées RADIUS

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

---

## **ÉTAPE 9: Maintenance**

### 9.1 Sauvegarder la base de données

```bash
# Sauvegarde complète
mysqldump -u root -p radius > backup_radius_$(date +%Y%m%d).sql

# Sauvegarder Wazuh
tar -czf backup_wazuh_$(date +%Y%m%d).tar.gz /var/ossec/etc
```

### 9.2 Restaurer une sauvegarde

```bash
# Si problème, restaurer
mysql -u root -p radius < backup_radius_20260131.sql
tar -xzf backup_wazuh_20260131.tar.gz -C /
```

### 9.3 Maintenance régulière

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
- [ ] Remplacez les certificats auto-signés par des certificats valides
- [ ] Activez HTTPS partout
- [ ] Configurez le firewall UFW
- [ ] Testez les sauvegardes
- [ ] Changez le secret RADIUS `testing123`

---

## 📊 Fichiers et structure

```
SAE501/
├── scripts/                    # Scripts d'installation
│   ├── install_mysql.sh        🎶 Base de données
│   ├── install_radius.sh       🎶 Serveur RADIUS (100% AUTONOME)
│   ├── install_php_admin.sh    🎶 Interface web (100% AUTONOME) 🆕
│   ├── install_wazuh.sh        🎶 Monitoring (100% AUTONOME)
│   ├── install_hardening.sh    🎶 Sécurité (recommandé)
│   ├── generate_certificates.sh
│   └── diagnostics.sh
│
├── radius/                     # Configuration RADIUS
│   ├── clients.conf            ✅ SEUL FICHIER REQUIS
│   └── sql/
│       ├── create_tables.sql
│       └── init_appuser.sql
│
├── docs/                       # Documentation
│   ├── HARDENING_GUIDE.md
│   ├── dossier-architecture.md
│   └── journal-de-bord.md
│
└── README.md                   # CE FICHIER

NOTE: Aucun dossier php-admin/ ou wazuh/ nécessaire!
Toutes les pages PHP et configurations sont générées automatiquement.
```

---

## 🛠️ Dépannage rapide

| Problème | Solution |
|----------|----------|
| PHP-Admin inaccessible | `sudo systemctl restart apache2 php-fpm` |
| Pages PHP manquantes | Relancer: `sudo bash scripts/install_php_admin.sh` |
| Erreur connexion DB | Vérifier MySQL: `sudo systemctl status mysql` |
| RADIUS ne démarre pas | `sudo freeradius -X` pour debug |
| Wazuh Dashboard HTTP 502 | Vérifier RAM: `free -h` - OpenSearch requiert 4GB+ |

---

## 📚 Commandes essentielles

```bash
# Installation modulaire (DANS L'ORDRE)
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh      # ✨ 100% AUTONOME
sudo bash scripts/install_php_admin.sh    # ✨ 100% AUTONOME 🆕
sudo bash scripts/install_wazuh.sh        # ✨ 100% AUTONOME
sudo bash scripts/install_hardening.sh    # RECOMMANDÉ

# Voir l'état du système
bash scripts/diagnostics.sh

# Tester l'authentification RADIUS
radtest testuser testpass localhost 0 testing123

# Voir logs RADIUS
sudo tail -f /var/log/freeradius/radius.log

# Accéder à PHP-Admin
http://VOTRE_IP/admin
User: admin | Pass: Admin@Secure123!

# Accéder au Wazuh Dashboard
http://VOTRE_IP:5601
User: admin | Pass: Admin@Wazuh123!

# Mode debug RADIUS
sudo freeradius -X

# Rebooter services
sudo systemctl restart freeradius mysql apache2
sudo systemctl restart wazuh-manager opensearch

# Sauvegarde
mysqldump -u root -p radius > backup.sql
tar -czf backup_wazuh.tar.gz /var/ossec/etc
```

---

## ✅ Checklist finale

- [ ] VM créée (8GB RAM, 2 CPU, 50GB disque)
- [ ] Debian/Ubuntu 22.04+ installé
- [ ] Repository SAE501 cloné
- [ ] Scripts exécutés dans l'ordre
- [ ] FreeRADIUS démarré et test `testuser` fonctionne
- [ ] **PHP-Admin accessible sur http://IP/admin** 🆕
- [ ] Mots de passe changés
- [ ] Secret RADIUS changé
- [ ] Wazuh Dashboard accessible (optionnel)
- [ ] Routeur configuré (RADIUS Server, secret)
- [ ] Utilisateur test créé en PHP-Admin
- [ ] Connexion Wi-Fi testée et fonctionnelle
- [ ] Logs d'audit consultés
- [ ] Firewall UFW configuré
- [ ] Sauvegardes planifiées

---

## 📄 Informations importantes

- **Installation modulaire**: 10-30 minutes selon composants
- **Flexibilité**: Installez uniquement ce dont vous avez besoin
- **RADIUS 100% autonome**: Aucun fichier externe requis (sauf `clients.conf`)
- **PHP-Admin 100% autonome**: 🆕 Toutes pages générées durant installation
- **Wazuh 100% autonome**: Manager + Dashboard en un seul script
- **Production-ready**: 95% après configuration
- **Guide sécurité complet**: `docs/HARDENING_GUIDE.md`

---

## 🚀 Prêt?

```bash
# Commencer l'installation modulaire:
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh      # ✨ 100% AUTONOME
sudo bash scripts/install_php_admin.sh    # ✨ 100% AUTONOME 🆕

# Optionnel - Monitoring:
sudo bash scripts/install_wazuh.sh       # ✨ 100% AUTONOME

# Recommandé - Sécurité:
sudo bash scripts/install_hardening.sh

# Vérifier l'installation:
bash scripts/diagnostics.sh

# Accéder à PHP-Admin:
http://VOTRE_IP/admin
User: admin | Pass: Admin@Secure123!

# Tester RADIUS:
radtest testuser testpass localhost 0 testing123
```

**Bonne chance! Le système est prêt pour la production. ✅**

---

*SAE501 - Projet SAE - Sorbonne Paris Nord*
*Dernière mise à jour: 31 janvier 2026*
*Version: 3.1 - PHP-Admin 100% autonome + RADIUS + Wazuh*

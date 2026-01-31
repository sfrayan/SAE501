# SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

## 🌟 But du projet

Créer une **infrastructure d'authentification RADIUS centralisée** pour une chaîne de salles de sport permettant:
- 🐫 Authentification WPA-Enterprise sécurisée (PEAP-MSCHAPv2)
- 👎 Gestion centralisée des utilisateurs
- 📊 Monitoring et détection d'anomalies
- 🔐 Logs d'audit complets
- 🏐 **Installation 100% autonome - ZÉRO fichier externe requis**
- 🛡️ **Hardening sécurité complet automatisé**
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
- 🛡️ **Hardening intégré automatique**

### **Wazuh** (Port 5601/1514)
- 🆕 **Monitoring en temps réel**
- 🔍 **Détection d'anomalies avancée**
- 🚨 **Alertes de sécurité personnalisées**
- 📊 **Dashboard OpenSearch interactif**
- ✨ **Installation 100% autonome - Zéro configuration manuelle**

### **Hardening Sécurité** 🛡️ 🆕
- 🔥 **UFW Firewall automatisé**
- 🔐 **SSH durci (chiffrement moderne)**
- 🛡️ **Kernel sécurisé (sysctl)**
- 🚫 **Fail2Ban anti-bruteforce**
- 📝 **Auditd (surveillance système)**
- 🌐 **Apache sécurisé (headers, modules)**
- 👤 **Politiques utilisateurs renforcées**
- ✨ **Installation en 1 commande - 100% automatisée**

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
chmod +x scripts/*.sh tests/*.sh
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

# 5. Appliquer le hardening sécurité - ⭐ FORTEMENT RECOMMANDÉ
# 🆕 VERSION 2.0 - HARDENING COMPLET AUTOMATISÉ!
# ✨ Configure AUTOMATIQUEMENT:
#    🔥 UFW Firewall (règles optimisées)
#    🔐 SSH durci (chiffrement moderne, restrictions)
#    🛡️ Paramètres kernel sécurisés (sysctl)
#    👤 Politiques utilisateurs (PAM, limites)
#    🚫 Fail2Ban (anti-bruteforce SSH/Apache)
#    📝 Auditd (surveillance fichiers critiques)
#    🌐 Apache sécurisé (headers, modules)
#    🗄️ MySQL sécurisé (logs, InnoDB)
#    📂 Permissions durcies (fichiers système)
sudo bash scripts/install_hardening.sh
```

**Durée estimée**: 
- **Sans Wazuh**: 10-15 minutes
- **Avec Wazuh**: 20-30 minutes (installation complète + Dashboard)
- **Hardening**: +2-3 minutes

**✨ Nouveautés Hardening v2.0**:
- ✅ **Installation en 1 commande** - Zéro configuration manuelle
- ✅ **9 modules de sécurité** activés automatiquement
- ✅ **UFW pré-configuré** avec règles optimales
- ✅ **SSH durci** selon les best practices
- ✅ **Fail2Ban** actif sur SSH et Apache
- ✅ **Auditd** surveille tous les fichiers critiques
- ✅ **Apache sécurisé** (headers CSP, XSS, modules)
- ✅ **MySQL durci** (logging, performance schema)
- ✅ **Politiques utilisateurs** renforcées (PAM)
- ✅ **Production-ready** en sortie d'installation

**Avantages de l'installation modulaire**:
- ✅ Contrôle total sur chaque composant
- ✅ Possibilité de sauter des modules (ex: Wazuh)
- ✅ Debugging facilité en cas de problème
- ✅ Installation personnalisée selon vos besoins

---

## **ÉTAPE 4: Vérifier l'installation**

### 4.1 Exécuter la suite complète de tests ✨ **NOUVEAU**

```bash
# Lancer tous les tests automatiques
sudo bash tests/run_all_tests.sh
```

**Ce script teste automatiquement**:
- ✅ Services (MySQL, FreeRADIUS, Apache, PHP-FPM)
- ✅ Connectivité réseau (ports 22, 80, 443, 1812, 1813, 3306)
- ✅ Base de données (tables, utilisateurs)
- ✅ Configuration RADIUS (modules SQL, EAP, clients)
- ✅ PHP-Admin (pages, permissions)
- ✅ UFW Firewall (actif, règles)
- ✅ SSH hardening (root disabled, chiffrement)
- ✅ Fail2Ban (jails SSH/Apache)
- ✅ Auditd (règles, surveillance)
- ✅ Kernel sysctl (ASLR, TCP cookies)
- ✅ Permissions fichiers sensibles
- ✅ Wazuh (si installé)
- ⚠️ Mots de passe par défaut (avertissement)

**Résultat attendu**:
```
================================================================
                    RÉSUMÉ DES TESTS
================================================================

Total des tests      : 65
Tests réussis       : 60
Tests échoués       : 0
Avertissements      : 5

Taux de réussite    : 92% 🎉

================================================================
  ✓ TOUS LES TESTS CRITIQUES RÉUSSIS!
  🎆 Installation SAE501 opérationnelle
================================================================
```

### 4.2 Diagnostics rapides (alternatif)

```bash
# Affiche l'état de tous les services
bash scripts/diagnostics.sh
```

Vous devriez voir:
- ✓ FreeRADIUS ACTIF
- ✓ MySQL ACTIF
- ✓ PHP-FPM ACTIF
- ✓ Apache2 ACTIF
- ✓ UFW ACTIF 🆕
- ✓ Fail2Ban ACTIF 🆕
- ✓ Auditd ACTIF 🆕
- ✓ Wazuh Manager ACTIF (si installé)
- ✓ OpenSearch ACTIF (si installé)

### 4.3 Tester l'authentification RADIUS

```bash
# Test avec l'utilisateur créé automatiquement
radtest testuser testpass localhost 0 testing123

# Vous devriez voir:
# Received Access-Accept
```

### 4.4 Accéder à PHP-Admin 🆕

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

## **ÉTAPE 5: Configuration Sécurité Avancée (⚠️ OBLIGATOIRE AVANT PRODUCTION!)**

### 5.1 CHANGER LES MOTS DE PASSE (⚠️ CRITIQUE!)

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

# 4. Changer Wazuh Dashboard (si installé):
# Accéder à http://VOTRE_IP:5601
# Utilisateur: admin
# Modifier le mot de passe dans Settings
```

### 5.2 Activer HTTPS (Recommandé)

```bash
# Installer Let's Encrypt pour certificat gratuit
sudo apt install certbot python3-certbot-apache -y

# Obtenir un certificat (nécessite un nom de domaine)
sudo certbot --apache -d votredomaine.com

# Renouvellement automatique
sudo systemctl enable certbot.timer
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

## **ÉTAPE 9: Maintenance et surveillance**

### 9.1 Sauvegarder la base de données

```bash
# Sauvegarde complète
mysqldump -u root -p radius > backup_radius_$(date +%Y%m%d).sql

# Sauvegarder Wazuh
tar -czf backup_wazuh_$(date +%Y%m%d).tar.gz /var/ossec/etc

# Sauvegarder configuration hardening
tar -czf backup_hardening_$(date +%Y%m%d).tar.gz \
  /etc/ssh/sshd_config \
  /etc/ufw \
  /etc/fail2ban \
  /etc/audit/rules.d \
  /etc/sysctl.d/99-sae501-hardening.conf
```

### 9.2 Restaurer une sauvegarde

```bash
# Si problème, restaurer
mysql -u root -p radius < backup_radius_20260131.sql
tar -xzf backup_wazuh_20260131.tar.gz -C /
tar -xzf backup_hardening_20260131.tar.gz -C /
```

### 9.3 Surveillance quotidienne

```bash
# Vérifier logs Fail2Ban
sudo fail2ban-client status sshd
sudo fail2ban-client status apache-auth

# Vérifier logs audit
sudo ausearch -k exec -ts today | tail -20
sudo ausearch -k sudoers_changes -ts today

# Vérifier activité réseau suspecte
sudo netstat -tulpn | grep LISTEN
sudo ss -tulpn

# Vérifier tentatives d'accès
sudo grep "Failed password" /var/log/auth.log | tail -20

# Vérifier modifications fichiers critiques
sudo ausearch -k sshd_config_changes -ts today
sudo ausearch -k mysql_config_changes -ts today
```

### 9.4 Maintenance régulière

```bash
# Chaque semaine:
# - Consulter les logs d'audit en PHP-Admin
# - Vérifier Wazuh Dashboard pour anomalies
# - Vérifier Fail2Ban (IPs bannies)
# - Faire une sauvegarde

# Chaque mois:
# - Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# - Vérifier les logs
sudo journalctl -u freeradius --since "1 month ago" | grep -i error
sudo journalctl -u wazuh-manager --since "1 month ago" | grep -i error

# - Vérifier l'espace disque
df -h
du -sh /var/log/*

# - Nettoyer vieux logs (si nécessaire)
sudo journalctl --vacuum-time=30d
```

---

## 🔐 Sécurité - POINTS CRITIQUES

### ⚠️ AVANT PRODUCTION

**OBLIGATOIRE**:
- [ ] 🚨 Changez TOUS les mots de passe par défaut (PHP-Admin, MySQL, Wazuh)
- [ ] 🚨 Changez le secret RADIUS `testing123` dans clients.conf
- [ ] 🔒 Activez HTTPS avec certificat SSL valide (Let's Encrypt)
- [ ] 🔥 Vérifiez les règles UFW (`ufw status verbose`)
- [ ] 📝 Vérifiez que auditd surveille les fichiers critiques
- [ ] 🚫 Vérifiez que Fail2Ban est actif (`fail2ban-client status`)
- [ ] 💾 Testez les sauvegardes (restauration)
- [ ] 🔍 Vérifiez les logs de sécurité quotidiennement

### 🛡️ Hardening appliqué automatiquement

Après exécution de `install_hardening.sh`, le système bénéficie de:

| Composant | Protection appliquée |
|-----------|----------------------|
| **UFW** | Firewall actif, deny incoming par défaut |
| **SSH** | Root désactivé, chiffrement moderne, max 3 tentatives |
| **Kernel** | ASLR max, core dumps désactivés, IP spoofing bloqué |
| **Fail2Ban** | Anti-bruteforce SSH + Apache, ban 3600s |
| **Auditd** | Surveillance fichiers critiques, logs immutables |
| **Apache** | Headers sécurité (CSP, XSS), modules vulnérables désactivés |
| **MySQL** | Users anonymes supprimés, remote root désactivé, logs activés |
| **PAM** | Politique mots de passe: 12 caract, 3 classes |
| **Permissions** | Fichiers système durcis (shadow 640, ssh keys 600) |

---

## 📊 Fichiers et structure

```
SAE501/
├── scripts/                    # Scripts d'installation
│   ├── install_mysql.sh        🎶 Base de données
│   ├── install_radius.sh       🎶 Serveur RADIUS (100% AUTONOME)
│   ├── install_php_admin.sh    🎶 Interface web (100% AUTONOME) 🆕
│   ├── install_wazuh.sh        🎶 Monitoring (100% AUTONOME)
│   ├── install_hardening.sh    🎶 Sécurité (100% AUTONOME) ⭐🆕
│   ├── generate_certificates.sh
│   └── diagnostics.sh
│
├── tests/                      # Tests automatisés ✨ NOUVEAU
│   ├── run_all_tests.sh        🧪 Suite complète de tests
│   ├── test_isolement.sh       Tests réseau spécialisés
│   ├── test_peap.sh            Tests PEAP-MSCHAPv2
│   └── test_syslog_mr100.sh    Tests monitoring MR100
│
├── radius/                     # Configuration RADIUS
│   ├── clients.conf            ✅ SEUL FICHIER REQUIS
│   └── sql/
│       ├── create_tables.sql
│       └── init_appuser.sql
│
├── docs/                       # Documentation
│   ├── analyse-ebios.md
│   ├── dossier-architecture.md
│   ├── wazuh-supervision.md
│   └── journal-de-bord.md
│
└── README.md                   # CE FICHIER

NOTE: Aucun dossier php-admin/, wazuh/ ou hardening/ nécessaire!
Toutes les configurations sont générées automatiquement par les scripts.
```

---

## 🛠️ Dépannage rapide

| Problème | Solution |
|----------|----------|
| Tests échoués | Relancer: `sudo bash tests/run_all_tests.sh` |
| PHP-Admin inaccessible | `sudo systemctl restart apache2 php-fpm` |
| Pages PHP manquantes | Relancer: `sudo bash scripts/install_php_admin.sh` |
| Erreur connexion DB | Vérifier MySQL: `sudo systemctl status mysql` |
| RADIUS ne démarre pas | `sudo freeradius -X` pour debug |
| Wazuh Dashboard HTTP 502 | Vérifier RAM: `free -h` - OpenSearch requiert 4GB+ |
| UFW bloque connexions | `sudo ufw status verbose` puis ajuster règles |
| Fail2Ban bans légitimes | `sudo fail2ban-client set sshd unbanip IP` |
| SSH impossible après hardening | Vérifier que votre user n'est pas 'root' |

---

## 📚 Commandes essentielles

### Installation
```bash
# Installation modulaire (DANS L'ORDRE)
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh      # ✨ 100% AUTONOME
sudo bash scripts/install_php_admin.sh    # ✨ 100% AUTONOME 🆕
sudo bash scripts/install_wazuh.sh        # ✨ 100% AUTONOME (OPTIONNEL)
sudo bash scripts/install_hardening.sh    # ✨ 100% AUTONOME ⭐🆕

# Voir l'état du système
bash scripts/diagnostics.sh

# Lancer tous les tests ✨ NOUVEAU
sudo bash tests/run_all_tests.sh
```

### Tests
```bash
# Suite complète de tests automatiques
sudo bash tests/run_all_tests.sh

# Tester l'authentification RADIUS
radtest testuser testpass localhost 0 testing123

# Tester hardening SSH
ssh -vvv user@localhost

# Tester firewall
sudo ufw status verbose
nmap -p 22,80,443,1812,1813,3306,5601 localhost
```

### Monitoring
```bash
# Logs RADIUS
sudo tail -f /var/log/freeradius/radius.log

# Logs Fail2Ban
sudo tail -f /var/log/fail2ban.log
sudo fail2ban-client status sshd

# Logs audit
sudo ausearch -k exec -ts today
sudo ausearch -k sshd_config_changes

# Logs Apache
sudo tail -f /var/log/apache2/error.log
```

### Interfaces web
```bash
# PHP-Admin
http://VOTRE_IP/admin
User: admin | Pass: Admin@Secure123!

# Wazuh Dashboard
http://VOTRE_IP:5601
User: admin | Pass: Admin@Wazuh123!
```

### Services
```bash
# Redémarrer services
sudo systemctl restart freeradius mysql apache2
sudo systemctl restart wazuh-manager opensearch
sudo systemctl restart fail2ban ssh ufw

# Voir statut
sudo systemctl status freeradius
sudo systemctl status fail2ban
sudo systemctl status auditd
```

### Sauvegardes
```bash
# Sauvegarde complète
mysqldump -u root -p radius > backup.sql
tar -czf backup_wazuh.tar.gz /var/ossec/etc
tar -czf backup_hardening.tar.gz /etc/ssh /etc/ufw /etc/fail2ban
```

---

## ✅ Checklist finale

### Installation
- [ ] VM créée (8GB RAM, 2 CPU, 50GB disque)
- [ ] Debian/Ubuntu 22.04+ installé
- [ ] Repository SAE501 cloné
- [ ] Scripts exécutés dans l'ordre
- [ ] **Tous les tests passés** (`sudo bash tests/run_all_tests.sh`) ✨
- [ ] FreeRADIUS démarré et test `testuser` fonctionne
- [ ] **PHP-Admin accessible sur http://IP/admin** 🆕
- [ ] **Hardening exécuté avec succès** ⭐🆕

### Sécurité
- [ ] 🚨 Mots de passe changés (PHP-Admin, MySQL, Wazuh)
- [ ] 🚨 Secret RADIUS changé dans clients.conf
- [ ] 🔥 UFW actif et configuré
- [ ] 🚫 Fail2Ban actif sur SSH et Apache
- [ ] 📝 Auditd surveille fichiers critiques
- [ ] 🔐 SSH durci (vérifier sshd_config)
- [ ] 🔒 HTTPS activé avec certificat valide

### Tests
- [ ] Wazuh Dashboard accessible (optionnel)
- [ ] Routeur configuré (RADIUS Server, secret)
- [ ] Utilisateur test créé en PHP-Admin
- [ ] Connexion Wi-Fi testée et fonctionnelle
- [ ] Logs d'audit consultés
- [ ] Sauvegardes testées (restauration)

### Production
- [ ] Surveillance quotidienne établie
- [ ] Procédure de sauvegarde automatisée
- [ ] Documentation interne rédigée
- [ ] Plan de réponse aux incidents

---

## 📄 Informations importantes

- **Installation modulaire**: 15-35 minutes selon composants
- **Flexibilité**: Installez uniquement ce dont vous avez besoin
- **RADIUS 100% autonome**: Aucun fichier externe requis (sauf `clients.conf`)
- **PHP-Admin 100% autonome**: 🆕 Toutes pages générées durant installation
- **Wazuh 100% autonome**: Manager + Dashboard en un seul script
- **Hardening 100% autonome**: ⭐🆕 9 modules de sécurité en 1 commande
- **Tests automatisés**: ✨ Suite complète pour validation
- **Production-ready**: 98% après configuration

---

## 🚀 Prêt?

```bash
# Installation complète recommandée:
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh       # ✨ 100% AUTONOME
sudo bash scripts/install_php_admin.sh     # ✨ 100% AUTONOME 🆕
sudo bash scripts/install_hardening.sh     # ✨ 100% AUTONOME ⭐🆕

# Optionnel - Monitoring avancé:
sudo bash scripts/install_wazuh.sh        # ✨ 100% AUTONOME

# Vérifier l'installation avec tests automatisés:
sudo bash tests/run_all_tests.sh          # ✨ NOUVEAU

# Diagnostics alternatifs:
bash scripts/diagnostics.sh

# Vérifier le hardening:
sudo ufw status verbose
sudo fail2ban-client status
sudo auditctl -l

# Accéder à PHP-Admin:
http://VOTRE_IP/admin
User: admin | Pass: Admin@Secure123!

# Tester RADIUS:
radtest testuser testpass localhost 0 testing123
```

**Le système est prêt pour la production après changement des mots de passe! ✅**

---

## 💬 Support et contribution

- **Issues**: [GitHub Issues](https://github.com/sfrayan/SAE501/issues)
- **Documentation**: Dossier `docs/`
- **Logs**: `/var/log/freeradius/`, `/var/log/apache2/`, `/var/log/mysql/`

---

*SAE501 - Projet SAE - Sorbonne Paris Nord*  
*Dernière mise à jour: 31 janvier 2026*  
*Version: 4.1 - Tests automatisés + Validation complète*

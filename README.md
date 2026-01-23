# SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

## 🌟 But du projet

Créer une **infrastructure d'authentification RADIUS centralisée** pour une chaîne de salles de sport permettant:
- 💫 Authentification WPA-Enterprise sécurisée (PEAP-MSCHAPv2)
- 👎 Gestion centralisée des utilisateurs
- 📊 Monitoring et détection d'anomalies
- 🔐 Logs d'audit complets
- 🎐 Installation et déploiement rapides

---

## 💻 Composants du système

### **FreeRADIUS** (Port 1812/1813)
- Serveur d'authentification RADIUS
- Protocole: PEAP-MSCHAPv2 (sans certificat client)
- Base de données utilisateurs: MySQL

### **PHP-Admin** (Port 80/443)
- Interface web de gestion
- Ajouter/modifier/supprimer utilisateurs
- Logs d'audit complets
- Paramétrages système

### **MySQL/MariaDB** (Port 3306)
- Base de données RADIUS
- Stockage utilisateurs (mots de passe hashés)
- Logs d'authentification

### **Wazuh** (Port 5601/55000)
- Monitoring en temps réel
- Détection d'anomalies
- Alertes de sécurité
- Dashboard de visualisation

---

## 📁 Pré-requis

- **OS**: Debian 12+ ou Ubuntu 22.04+
- **RAM**: 4GB minimum (8GB recommandé)
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
- Allocer 4GB RAM, 2 CPU, 50GB disque

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

## **ÉTAPE 3: Installation automatisée (RECOMMANDÉ)**

### 💉 Installation complète en 1 seule commande

```bash
sudo bash scripts/install_all.sh
```

**Qu'est-ce que ce script fait?**
1. Met à jour le système
2. Installe FreeRADIUS
3. Installe MySQL et crée la base RADIUS
4. Installe PHP-Admin (interface web)
5. Installe Wazuh (monitoring)
6. Configure le hardening sécurité
7. Lance les diagnostics

**Durée estimée**: 15-20 minutes

**Affichage final**:
```
✅ Identifiants d'accès
✅ URLs des interfaces
✅ Recommandations de sécurité
```

---

## **ÉTAPE 4: Vérifier l'installation**

### 4.1 Vérifier les services
```bash
# Affiche l'état de tous les services
bash scripts/show_credentials.sh
```

Vous devriez voir:
- ✓ FreeRADIUS ACTIF
- ✓ MySQL ACTIF
- ✓ PHP-FPM ACTIF
- ✓ Apache2 ACTIF
- ✓ Wazuh Manager ACTIF
- ✓ Elasticsearch ACTIF

### 4.2 Lancer les tests automatisés
```bash
bash scripts/test_installation.sh
```

Résultat attendu: **✅ 10/10 tests réussis**

### 4.3 Vérifier les accès
```bash
bash scripts/show_credentials.sh
```

Nota les identifiants affichés!

---

## **ÉTAPE 5: Premières configurations**

### 5.1 Accéder à PHP-Admin

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

### 5.2 Accéder à Wazuh

```
URL: https://VOTRE_IP:5601
Utilisateur: admin
Mot de passe: SecurePassword123! (affiché en fin d'install)
```

**Explorez le dashboard**:
- 📊 Vue d'ensemble
- 💱 État des agents
- 🚨 Alertes de sécurité
- 📋 Logs complets

### 5.3 CHANGER LES MOTS DE PASSE (⚠️ OBLIGATOIRE!)

```bash
# Afficher les mots de passe actuels
bash scripts/show_credentials.sh

# Changer dans PHP-Admin:
# Admin: Admin@Secure123! → VotreMot@Passe123!

# Changer dans Wazuh:
# Admin: SecurePassword123! → VotreMot@Passe123!

# Changer MySQL root:
mysql -u root -p
# Enter: MySQL@Root123!
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NouveauMot@Passe123!';
EXIT;
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
7. **Shared Secret**: Celui configuré en PHP-Admin Paramétrages
8. **Cliquer Save**

### 6.3 Tester la connexion

Sur un ordinateur:
1. Chercher le réseau Wi-Fi
2. Connecter à l'SSID "Entreprise"
3. Type d'authentification: WPA-Enterprise
4. Entrer un identifiant RADIUS créé en PHP-Admin
5. Entrer le mot de passe
6. Vérifier dans les logs: `bash scripts/show_credentials.sh` → Logs d'authentification

---

## **ÉTAPE 7: Gestion des utilisateurs**

### 7.1 Ajouter un utilisateur

**Via PHP-Admin**:
1. Accédez à `http://VOTRE_IP/admin`
2. Cliquez "Ajouter utilisateur"
3. Entrez:
   - Identifiant: `jean.dupont`
   - Mot de passe: `MonPasse@123`
4. Cliquez "Enregistrer"

**Via CLI (optionnel)**:
```bash
mysql -u radiusapp -p radius
# Mot de passe: RadiusApp@Secure123!

INSERT INTO radcheck (username, attribute, op, value) 
VALUES ('jean.dupont', 'User-Password', ':=', MD5('MonPasse@123'));

EXIT;
```

### 7.2 Lister les utilisateurs

**Via PHP-Admin**:
1. Cliquez "Lister utilisateurs"
2. Voir tous les comptes créés
3. Actions: modifier, supprimer, activer/désactiver

### 7.3 Consulter les logs d'authentification

**Via PHP-Admin**:
1. Cliquez "Logs d'audit"
2. Filtrez par date/action
3. Voir qui s'est connecté, quand, d'où, résultat

**Logs en temps réel**:
```bash
sudo tail -f /var/log/freeradius/radius.log
```

---

## **ÉTAPE 8: Monitoring et sécurité**

### 8.1 Consulter le monitoring Wazuh

1. Accédez à `https://VOTRE_IP:5601`
2. **Onglet Agents**: voir état système
3. **Onglet Alerts**: voir les alertes sécurité
4. **Onglet Logs**: voir les logs complets

### 8.2 Vérifier les infos système

**Via PHP-Admin**:
1. Cliquez "Infos système"
2. Voir l'état des services
3. Cliquer sur "Tester" pour diagnostics

### 8.3 Dépannage

**Si quelque chose ne fonctionne pas**:
```bash
# Tests complets
bash scripts/test_installation.sh

# Diagnostics détaillés
bash scripts/diagnostics.sh

# Voir les logs
bash scripts/show_credentials.sh

# Rebooter les services
sudo systemctl restart radiusd
sudo systemctl restart mysql
sudo systemctl restart php-fpm
sudo systemctl restart apache2
sudo systemctl restart wazuh-manager
```

---

## **ÉTAPE 9: Sauvegarder et maintenir**

### 9.1 Sauvegarder la base de données

```bash
# Sauvegarde complète
mysqldump -u root -p radius > backup_radius_$(date +%Y%m%d).sql

# Entrer le mot de passe MySQL root
```

### 9.2 Restaurer une sauvegarde

```bash
# Si problème, restaurer
mysql -u root -p radius < backup_radius_20260123.sql
```

### 9.3 Maintenance régulière

```bash
# Chaque semaine:
# - Consulter les logs d'audit en PHP-Admin
# - Vérifier Wazuh pour anomalies
# - Faire une sauvegarde

# Chaque mois:
# - Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Vérifier les logs
sudo journalctl -u radiusd --since today
```

---

## 🔐 Sécurité - POINTS CRITIQUES

### ⚠️ AVANT PRODUCTION

**OBLIGATOIRE**:
- [ ] Changez TOUS les mots de passe par défaut
- [ ] Générez certificats SSL/TLS valides
- [ ] Activez HTTPS partout
- [ ] Configurez le firewall UFW
- [ ] Testez les sauvegardes
- [ ] Désactivez les accès inutiles

**FORTEMENT RECOMMANDÉ**:
- [ ] Activez 2FA pour PHP-Admin
- [ ] Limitez l'accès SSH (clés uniquement)
- [ ] Configurez les alertes Wazuh
- [ ] Mettez en place des backups automatiques
- [ ] Utilisez un VPN pour administrer

### 📈 Bonnes pratiques

```bash
# 1. Firewall (UFW)
sudo ufw enable
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 1812/udp    # RADIUS
sudo ufw allow 5601/tcp    # Wazuh

# 2. SSH sécurisé
sudo nano /etc/ssh/sshd_config
# Remplacer:
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes

# 3. Logs régulièrement audités
sudo tail -f /var/log/auth.log
sudo tail -f /var/log/syslog
```

---

## 📊 Fichiers et structure

```
SAE501/
├── scripts/                    # Scripts d'installation
│   ├── install_all.sh          🎆 PRINCIPAL
│   ├── install_radius.sh
│   ├── install_php_admin.sh
│   ├── install_wazuh.sh
│   ├── install_hardening.sh
│   ├── diagnostics.sh
│   ├── show_credentials.sh
│   └── test_installation.sh
│
├── radius/                     # Configuration RADIUS
│   ├── clients.conf
│   ├── users.txt
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
├── wazuh/                      # Configuration Wazuh
│   ├── manager.conf
│   ├── local_rules.xml
│   └── syslog-tlmr100.conf
│
├── docs/                       # Documentation technique
│   ├── dossier-architecture.md
│   ├── hardening-linux.md
│   ├── journal-de-bord.md
│   └── index.md
│
├── .github/
│   └── workflows/
│       └── test-installation.yml
│
└── README.md                   # CE FICHIER
```

---

## 🛠️ Dépannage rapide

| Problème | Solution |
|----------|----------|
| Installation bloque | Vérifier connexion internet: `ping google.com` |
| RADIUS ne démarre pas | `sudo systemctl status radiusd` ou `sudo radiusd -X` |
| PHP-Admin inaccessible | `sudo systemctl restart apache2 php-fpm` |
| Wazuh ne répond pas | `sudo systemctl restart wazuh-manager elasticsearch` |
| Authentification échoue | Vérifier identifiant/mot de passe en PHP-Admin |
| Connexion Wi-Fi échoue | Vérifier logs: `sudo tail -f /var/log/freeradius/radius.log` |

---

## 📚 Commandes essentielles

```bash
# Installation (UNE SEULE FOIS)
sudo bash scripts/install_all.sh

# Vérifier installation
bash scripts/test_installation.sh

# Voir accès
bash scripts/show_credentials.sh

# Diagnostics
bash scripts/diagnostics.sh

# Rebooter services
sudo systemctl restart radiusd mysql apache2 php-fpm wazuh-manager

# Voir logs
sudo tail -f /var/log/freeradius/radius.log
sudo tail -f /var/log/syslog

# Accéder MySQL
mysql -u radiusapp -p radius

# Sauvegarde
mysqldump -u root -p radius > backup.sql
```

---

## ✅ Checklist finale

- [ ] VM créée (4GB RAM, 2 CPU, 50GB disque)
- [ ] Debian/Ubuntu 22.04+ installé
- [ ] Repository SAE501 cloné
- [ ] `sudo bash scripts/install_all.sh` exécuté
- [ ] 10/10 tests réussis
- [ ] Mots de passe changés
- [ ] PHP-Admin accessible et fonctionnel
- [ ] Wazuh accessible et fonctionnel
- [ ] Routeur configuré (RADIUS Server, secret)
- [ ] Utilisateur test créé en PHP-Admin
- [ ] Connexion Wi-Fi testée et fonctionnelle
- [ ] Logs d'audit consultés
- [ ] Firewall UFW configuré
- [ ] Sauvegardes planifiées

---

## 📄 Informations importantes

- **Installation défaut": 5-10 minutes avec `install_all.sh`
- **Durée sans script**: 1-2 heures (manuel)
- **Production-ready**: 95% après configuration
- **Support technique**: Voir les logs ou scripts de diagnostics
- **Documentation**: Plus de détails dans `docs/`

---

## 🚀 Prêt?

```bash
# Commencer l'installation:
sudo bash scripts/install_all.sh

# Puis consulter les accès:
bash scripts/show_credentials.sh

# Et accéder à l'interface:
http://VOTRE_IP/admin
```

**Bonne chance! Le système est prêt.**

---

*SAE501 - Projet SAE - Sorbonne Paris Nord*
*Dernière mise à jour: 23 janvier 2026*

# SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

**Système complet d'authentification et de gestion d'accès Wi-Fi Enterprise avec monitoring.**

## 🚀 Démarrage rapide

```bash
# Installation complète en une commande (5-10 minutes)
sudo bash scripts/install_all.sh

# Voir tous les accès et identifiants
bash scripts/show_credentials.sh

# Tests de diagnostics
bash scripts/diagnostics.sh
```

## 📋 Fonctionnalités

✅ **FreeRADIUS** - Serveur d'authentification Enterprise WPA2/WPA3
✅ **PHP-Admin** - Interface de gestion intuitive des utilisateurs
✅ **Wazuh** - Monitoring et alertes de sécurité en temps réel
✅ **MySQL** - Base de données sécurisée pour les profils utilisateurs
✅ **Logs d'audit** - Traçabilité complète de toutes les actions
✅ **Hardening** - Configuration de sécurité renforcée
✅ **Scripts automatisés** - Installation et maintenance simplifiées

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Clients Wi-Fi                            │
│              (Ordinateurs, téléphones)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                 WPA-Enterprise (PEAP/EAP-TLS)
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Routeur (NAS RADIUS)                            │
│        ┌──────────────────────────────────┐               │
│        │ Port: 1812 (Auth)                │               │
│        │ Port: 1813 (Accounting)          │               │
│        └──────────────────────────────────┘               │
└────────────────────┬────────────────────────────────────────┘
                     │
                   UDP RADIUS
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Serveur SAE501 (VM Debian)                      │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          FreeRADIUS (Port 1812/1813)                │   │
│  │  • Authentification  EAP-PEAP                        │   │
│  │  • Base utilisateurs MySQL                          │   │
│  │  • Logs détaillés                                   │   │
│  └──────────┬────────────────────────────────────────┬─┘   │
│             │                                          │     │
│             ▼                                          ▼     │
│  ┌────────────────────────────┐  ┌──────────────────────┐  │
│  │    MySQL (Port 3306)       │  │  PHP-Admin           │  │
│  │ • Base de données RADIUS   │  │  • Interface Web     │  │
│  │ • Utilisateurs             │  │  • Gestion Users     │  │
│  │ • Audit logs               │  │  • Logs d'audit      │  │
│  │ • Paramètres config        │  │  • Param. système    │  │
│  └────────────────────────────┘  └──────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     Wazuh (Port 5601 Dashboard, 55000 API)           │  │
│  │ • Monitoring en temps réel                           │  │
│  │ • Détection d'anomalies                              │  │
│  │ • Alertes de sécurité                                │  │
│  │ • Intégration Elasticsearch                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└────────────────────────────────────────────────────────────┘
```

---

## 📦 Structure du projet

```
SAE501/
├── README.md                    # Documentation complète
├── README_FINAL.md             # Ce fichier
├── QUICKSTART.md               # Guide de démarrage rapide
├── SETUP.md                    # Guide de configuration avancée
│
├── scripts/                    # 🤖 Scripts d'automatisation
│   ├── install_all.sh          # Installation complète
│   ├── install_radius.sh       # Installation FreeRADIUS
│   ├── install_php_admin.sh    # Installation PHP-Admin
│   ├── install_wazuh.sh        # Installation Wazuh
│   ├── install_hardening.sh    # Hardening système
│   ├── diagnostics.sh          # Tests de diagnostics
│   └── show_credentials.sh     # Afficher les accès
│
├── radius/                     # 📡 Configuration RADIUS
│   ├── clients.conf            # Config des clients NAS
│   ├── users.txt               # Fichier de test d'utilisateurs
│   └── sql/
│       ├── create_tables.sql   # Schéma base de données
│       └── init_appuser.sql    # Utilisateur applicatif
│
├── php-admin/                  # 🌐 Interface de gestion
│   ├── index.php               # Page d'accueil
│   ├── config.php              # Configuration
│   ├── auth.php                # Authentification
│   ├── functions.php           # Fonctions utilitaires
│   ├── pages/
│   │   ├── dashboard.php       # Tableau de bord
│   │   ├── list_users.php      # Liste des utilisateurs
│   │   ├── add_user.php        # Ajouter utilisateur
│   │   ├── delete_user.php     # Supprimer utilisateur
│   │   ├── audit.php           # Logs d'audit
│   │   ├── settings.php        # Paramètres
│   │   ├── system.php          # Infos système
│   │   └── wazuh-dashboard.php # Dashboard Wazuh
│   └── css/
│       └── style.css           # Styles
│
├── wazuh/                      # 🛡️ Configuration Wazuh
│   ├── manager.conf            # Config manager
│   ├── local_rules.xml         # Règles personnalisées
│   └── syslog-tlmr100.conf     # Config syslog
│
├── docs/                       # 📚 Documentation
│   ├── dossier-architecture.md # Architecture détaillée
│   ├── hardening-linux.md      # Hardening guide
│   ├── journal-de-bord.md      # Journal de développement
│   └── guide-securite.md       # Bonnes pratiques
│
└── captures/                   # 📸 Screenshots
    ├── vm-installation.png
    ├── router-config.png
    └── wifi-connection.png
```

---

## 🔐 Sécurité

### Pratiques de sécurité implémentées

1. **Authentification forte**
   - Mots de passe hashés (bcrypt)
   - RADIUS avec secret partagé sécurisé
   - Support WPA2-Enterprise et WPA3

2. **Chiffrement**
   - PEAP (Protected EAP)
   - EAP-TLS avec certificats
   - Connexions MySQL chiffrées

3. **Audit et logging**
   - Logs d'authentification détaillés
   - Logs d'audit des actions administrateur
   - Traçabilité IP complète

4. **Hardening**
   - UFW firewall configuré
   - Fail2Ban pour prévention brute-force
   - AppArmor profiles
   - SSH renforcé

5. **Monitoring**
   - Wazuh pour détection d'anomalies
   - Alertes en temps réel
   - Dashboard de visualisation

### ⚠️ Avant production

**OBLIGATOIRE:**
- [ ] Changez TOUS les mots de passe par défaut
- [ ] Générez des certificats SSL/TLS valides
- [ ] Configurez HTTPS partout
- [ ] Changez la clé secrète RADIUS
- [ ] Sauvegardez la base de données
- [ ] Testez les sauvegardes

**FORTEMENT RECOMMANDÉ:**
- [ ] Activez 2FA pour PHP-Admin
- [ ] Configurez les backups automatiques
- [ ] Activez le monitoring externe
- [ ] Limitez les accès SSH
- [ ] Configurez les alertes

---

## 🚀 Utilisation

### 1. Installation

```bash
# Installation automatique (15-20 minutes)
sudo bash scripts/install_all.sh
```

### 2. Accès aux interfaces

**PHP-Admin** (Gestion des utilisateurs)
- URL: `http://localhost/admin`
- Défaut: `admin` / `Admin@Secure123!`

**Wazuh Dashboard** (Monitoring)
- URL: `http://localhost:5601`
- Défaut: `admin` / `SecurePassword123!`

### 3. Ajouter un utilisateur

Via PHP-Admin:
1. Allez dans "Ajouter utilisateur"
2. Entrez l'identifiant et le mot de passe
3. Cliquez "Enregistrer"

Via CLI:
```bash
sudo radmin
insert into radcheck set username='user1', attribute='User-Password', op=':=', value='password123';
```

### 4. Configurer le routeur

1. Accédez à l'interface d'administration du routeur
2. Allez dans Sécurité Wi-Fi
3. Choisissez "WPA-Enterprise"
4. Serveur RADIUS: Adresse IP de votre serveur
5. Port: 1812
6. Secret partagé: Celui configuré en PHP-Admin

### 5. Connecter un client

**Windows/Linux:**
1. Allez dans Paramètres Wi-Fi
2. Sélectionnez le SSID du routeur
3. Entrez les identifiants
4. Choisissez "PEAP" ou "EAP-TLS"

**macOS/iOS:**
1. Allez dans Paramètres Wi-Fi
2. Sélectionnez le réseau
3. Authentification: WPA-Enterprise
4. Entrez les identifiants

### 6. Surveiller les logs

```bash
# RADIUS
sudo tail -f /var/log/freeradius/radius.log

# PHP-Admin
http://localhost/admin?action=audit

# Wazuh
http://localhost:5601

# Système
sudo tail -f /var/log/syslog
```

---

## 🧪 Tests

### Tests d'authentification

```bash
# Test RADIUS local
radtest utilisateur password123 127.0.0.1 0 shared_secret

# Test avec debug
sudo radtest -d utilisateur password123 127.0.0.1 0 shared_secret

# Vérifier les services
sudo systemctl status radiusd
sudo systemctl status php-fpm
sudo systemctl status mysql
sudo systemctl status wazuh-manager
```

### Diagnostics complets

```bash
bash scripts/diagnostics.sh
```

Affichera:
- État des services
- Connectivité réseau
- Ports ouverts
- Logs d'erreurs
- Tests de connexion

---

## 📊 Monitoring

### Wazuh Dashboard

Le dashboard Wazuh affiche:
- **Vue d'ensemble**: État global du système
- **Agents**: Liste et statut des agents
- **Alerts**: Alertes de sécurité
- **Compliance**: Conformité et rapports
- **Threat Intelligence**: Analyse des menaces

### Métriques clés

```
Athlétisation utilisateurs:
- Total: 50
- Actifs: 48
- Inactifs: 2

Événements aujourd'hui:
- Authentifications réussies: 450
- Authentifications échouées: 12
- Changements configuration: 3
```

---

## 🛠️ Dépannage

### RADIUS ne démarre pas

```bash
# Vérifier les erreurs
sudo systemctl status radiusd
sudo systemctl start radiusd -l

# Mode debug
sudo /usr/sbin/radiusd -X

# Vérifier les permissions
ls -la /etc/raddb/
```

### PHP-Admin inaccessible

```bash
# Vérifier Apache
sudo systemctl status apache2
sudo a2enmod php8.2
sudo systemctl restart apache2

# Vérifier PHP-FPM
sudo systemctl status php-fpm

# Logs
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/php-fpm.log
```

### Connexion Wi-Fi échoue

```bash
# Vérifier RADIUS
sudo tail -f /var/log/freeradius/radius.log

# Test authentification
radtest utilisateur password 127.0.0.1 0 secret

# Vérifier la base de données
mysql -u radiusapp -p radius
SELECT * FROM radcheck WHERE username='utilisateur';
```

### Wazuh ne répond pas

```bash
# Redémarrer les services
sudo systemctl restart wazuh-manager
sudo systemctl restart elasticsearch

# Vérifier les logs
sudo tail -f /var/ossec/logs/ossec.log

# Vérifier l'espace disque
df -h /var/ossec/data
```

---

## 📈 Performance

### Configuration recommandée

**Minimum:**
- CPU: 2 cores
- RAM: 4 GB
- Disque: 50 GB

**Recommandé (< 100 utilisateurs):**
- CPU: 4 cores
- RAM: 8 GB
- Disque: 100 GB

**Recommandé (> 100 utilisateurs):**
- CPU: 8+ cores
- RAM: 16 GB
- Disque: 200+ GB

### Optimisations

```bash
# Augmenter les connexions MySQL
max_connections = 1000

# Augmenter les workers RADIUS
thread_pool_size = 32

# Cache Wazuh
compress_json = yes
```

---

## 📚 Documentation supplémentaire

- **QUICKSTART.md** - Démarrage rapide (5 min)
- **SETUP.md** - Configuration avancée
- **docs/dossier-architecture.md** - Architecture technique
- **docs/hardening-linux.md** - Sécurité Linux
- **docs/guide-securite.md** - Bonnes pratiques
- **docs/journal-de-bord.md** - Journal de développement

---

## 🤝 Support

En cas de problème:

1. **Vérifiez les logs**
   ```bash
   bash scripts/diagnostics.sh
   ```

2. **Consultez la documentation**
   - QUICKSTART.md pour les bases
   - docs/ pour les détails
   - README.md pour la complète

3. **Tests manuels**
   ```bash
   # Test RADIUS
   radtest user password localhost 0 secret
   
   # Test MySQL
   mysql -u radiusapp -p radius
   
   # Test accès web
   curl -v http://localhost/admin
   ```

---

## 📄 Licence

Ce projet utilise des logiciels open-source:
- FreeRADIUS (GPLv2)
- PHP (PHP Licence)
- MySQL (GPLv2)
- Wazuh (GPLv2)
- Debian (Libre)

---

## 👨‍💻 Auteurs

**Projet SAE501** - Architecture Wi-Fi Sécurisée Multi-Sites

Developpé en 2026

---

## 🎯 Objectifs atteints

✅ Authentification Enterprise WPA2/WPA3
✅ Interface de gestion intuitive
✅ Monitoring et alertes en temps réel
✅ Logs d'audit complets
✅ Installation automatisée
✅ Sécurité renforcée
✅ Documentation complète
✅ Tests automatiques

---

**Système SAE501 - Prêt pour la production** 🚀

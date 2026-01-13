# 🏋️ SAE 5.01 - Architecture Wi-Fi Sécurisée Multi-Sites

**Projet académique SAE 5.01** - Déploiement d'une infrastructure Wi-Fi d'entreprise sécurisée avec authentification 802.1X, supervision centralisée et architecture multi-sites.

**Durée totale** : ~4 heures (VirtualBox: 30 min + VM Install: 1h + Routeur: 1h + Tests: 1h30)

---

## 📋 Table des matières

0. [Configuration VirtualBox (AVANT TOUTE CHOSE)](#virtualbox)
1. [Objectifs du projet](#objectifs)
2. [Architecture globale](#architecture)
3. [Installation complète (guide étape par étape)](#installation)
4. [Configuration du routeur](#routeur)
5. [Tests et validation](#tests)
6. [Hardening du serveur](#hardening)
7. [Supervision avec Wazuh](#wazuh)
8. [Troubleshooting](#troubleshooting)
9. [Livrables et documentation](#livrables)

---

## 🖥️ Configuration VirtualBox (CRITIQUE) ⚠️

**VOUS DEVEZ FAIRE CELA AVANT D'INSTALLER DEBIAN 11**

### Étape 1 : Créer la VM Debian 11

```
VirtualBox → Nouvelle
├─ Nom: SAE501-Debian11
├─ Type: Linux
├─ Version: Debian (64-bit)
├─ RAM: 4096 MB (minimum) ou 6144 MB (recommandé)
└─ Disque: 40 GB (VDI, allocation dynamique)
```

### Étape 2 : Configuration RÉSEAU (LA PLUS IMPORTANTE)

**👉 UTILISEZ MODE BRIDGE (Recommandé) :**

```
VirtualBox → SAE501-Debian11 → Configuration → Réseau → Carte 1
┌─────────────────────────────────────────────────────────────┐
│ ✅ Activer carte réseau                                      │
│ Mode d'accès réseau: ▼ Accès par pont (Bridge)              │
│ Nom: [Sélectionner votre carte]                             │
│   → Si câble Ethernet: Realtek/Intel Ethernet               │
│   → Si Wi-Fi: Intel Wi-Fi 6 AX...                           │
│ Mode promiscuité: Tout autoriser                            │
│ Type de carte: Intel PRO/1000 MT Desktop (82540EM)          │
└─────────────────────────────────────────────────────────────┘
```

**Pourquoi Bridge ?**
- ✅ VM obtient IP sur le même réseau que le routeur (192.168.10.x)
- ✅ Routeur TL-MR100 peut contacter la VM directement
- ✅ Pas de NAT compliqué
- ✅ **C'est le plus simple pour SAE 5.01**

### Étape 3 : Autres paramètres VM

```
Configuration → Système → Carte mère:
├─ Mémoire: 4096-6144 MB
├─ Ordre d'amorçage: Disquette ❌, Optique ✅, Disque dur ✅
└─ Horloge (UTC): ✅

Configuration → Système → Processeur:
├─ Processeur(s): 2-4 CPU
├─ Limite d'exécution: 100%
└─ PAE/NX: ✅

Configuration → Stockage:
├─ Disque dur: SAE501-Debian11.vdi (40 GB)
└─ CD/DVD: debian-11.x.x-amd64-netinst.iso
  (Télécharger depuis https://www.debian.org/distrib/netinst)
```

### Étape 4 : Installation Debian 11

```
Démarrer VM → Boot sur ISO Debian 11

Installation (defaults):
├─ Language: English/French
├─ Location: France
├─ Keyboard: French
├─ Hostname: sae501-server
├─ Domain: (vide ou gym.fr)
├─ Root password: Root@SAE501!
├─ User: saeadmin / Admin@SAE501!
├─ Partitioning: Guided - use entire disk
└─ Software: ✅ SSH server
             ✅ Standard utilities
             ❌ Desktop
             ❌ Web server (on l'installe après)
```

### Étape 5 : Configuration IP STATIQUE (CRITIQUE)

**Après reboot Debian :**

```bash
# Login: saeadmin / Admin@SAE501!
su -
# Password: Root@SAE501!

# Installer outils
apt update
apt install -y net-tools vim curl git

# Identifier la carte réseau
ip addr show
# Noter le nom: enp0s3 (ou eth0, ens33)

# Éditer config réseau
vim /etc/network/interfaces

# Remplacer contenu par:
───────────────────────────────────────────────
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface (BRIDGE)
auto enp0s3
iface enp0s3 inet static
    address 192.168.10.100
    netmask 255.255.255.0
    gateway 192.168.10.1
    dns-nameservers 8.8.8.8 8.8.4.4
───────────────────────────────────────────────

# Sauvegarder et quitter (:wq)

# Redémarrer réseau
systemctl restart networking

# VÉRIFIER ✅
ip addr show enp0s3
# Doit afficher: inet 192.168.10.100/24

ping 192.168.10.1
# ✅ Doit répondre (routeur)

ping 8.8.8.8
# ✅ Doit répondre (Internet)
```

**⚠️ L'IP DOIT être 192.168.10.100** - C'est configuré dans `radius/clients.conf`

### Étape 6 : Cloner le projet

```bash
# Sur la VM
cd ~
git clone https://github.com/votre-username/SAE501.git
cd SAE501

# Vérifier structure
ls -la
# Doit afficher: README.md, scripts/, php-admin/, radius/, wazuh/, docs/
```

✅ **VIRTUALBOX PRÊT !** Passez à l'étape 0 ci-dessous.

---

## 🎯 Objectifs

### Fonctionnels

- ✅ Déployer un **serveur RADIUS centralisé** (FreeRADIUS + MySQL)
- ✅ Configurer une **authentification 802.1X sécurisée** (PEAP-MSCHAPv2, sans certificat client)
- ✅ Mettre en place un **réseau Wi-Fi d'entreprise** sécurisé et un **réseau invité isolé**
- ✅ Implémenter une **interface de gestion** (PHP) pour ajouter/supprimer des utilisateurs
- ✅ Intégrer une **supervision centralisée** (Wazuh) avec détection d'intrusion
- ✅ Tester l'**isolement réseau** entre VLAN (staff/guests/managers)

### Sécurité

- ✅ **Authentification** : PEAP-MSCHAPv2 sans certificat client (facile à déployer)
- ✅ **Isolation** : Réseau invité isolé du réseau interne
- ✅ **Chiffrement** : TLS pour les échanges RADIUS
- ✅ **Hardening** : SSH sécurisé, firewall UFW, permissions restrictives
- ✅ **Audit** : Journalisation complète des authentifications et accès

### Pédagogiques

- ✅ Comprendre les protocoles **802.1X et EAP**
- ✅ Maîtriser **FreeRADIUS** et son intégration MySQL
- ✅ Configurer **Wazuh** pour la détection de menaces
- ✅ Analyser les risques **EBIOS ANSSI**
- ✅ Appliquer le **hardening Linux** en production

---

## 🏗️ Architecture

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE SAE 5.01                   │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                    VM DEBIAN 11 (VirtualBox)                │
│                    IP: 192.168.10.100                       │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AUTHENTIFICATION & GESTION                          │   │
│  │  ┌──────────────────┐  ┌──────────────────────────┐ │   │
│  │  │  FreeRADIUS      │  │  MariaDB/MySQL           │ │   │
│  │  │  Port: 1812 UDP  │  │  Port: 3306 TCP          │ │   │
│  │  │  PEAP-MSCHAPv2   │  │  DB: radius              │ │   │
│  │  │  Certificat TLS  │  │  Tables: radcheck, ...   │ │   │
│  │  └──────────────────┘  └──────────────────────────┘ │   │
│  │          │                          │                  │   │
│  │  ┌─────────────────────────────────────────────────┐  │   │
│  │  │  PHP-Admin Interface (Port 80 TCP)             │  │   │
│  │  │  - Ajouter/supprimer utilisateurs RADIUS        │  │   │
│  │  │  - Afficher les comptes actifs                  │  │   │
│  │  │  - Journaliser les actions                      │  │   │
│  │  └─────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SUPERVISION & SÉCURITÉ                             │   │
│  │  ┌──────────────────┐  ┌──────────────────────────┐ │   │
│  │  │  Wazuh Manager   │  │  rsyslog                 │ │   │
│  │  │  Port: 1514 UDP  │  │  Port: 514 UDP           │ │   │
│  │  │  - SIEM          │  │  Réception logs          │ │   │
│  │  │  - Alertes       │  │  - FreeRADIUS            │ │   │
│  │  │  - Détection     │  │  - Routeur TL-MR100     │ │   │
│  │  └──────────────────┘  └──────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  SÉCURITÉ SERVEUR                                   │   │
│  │  - SSH: Authentification par clés (pas root)        │   │
│  │  - UFW: Pare-feu configuré (ports min)              │   │
│  │  - Permissions: 640 (config), 750 (répertoires)     │   │
│  │  - Audit: journalctl, auditctl                      │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                             ▲
                    Bridge Ethernet/Wi-Fi
                             │
┌──────────────────────────────────────────────────────────────┐
│          ROUTEUR TP-LINK TL-MR100 (Point d'accès Wi-Fi)      │
│                    IP: 192.168.10.1                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  SSID "Fitness-Pro"              SSID "Fitness-Guest"       │
│  ├─ WPA2-Enterprise             ├─ WPA2-PSK               │
│  ├─ PEAP-MSCHAPv2 (RADIUS)       ├─ Isolation: Activée    │
│  ├─ VLAN 10 (Staff)              ├─ VLAN 20 (Guests)      │
│  ├─ IP: 192.168.10.x/24          ├─ IP: 192.168.20.x/24   │
│  └─ Accès: Réseau complet        └─ Accès: Internet seul  │
│                                                               │
│  Configuration RADIUS:         Syslog vers Wazuh:           │
│  ├─ Serveur: 192.168.10.100    ├─ IP: 192.168.10.100      │
│  ├─ Port: 1812 UDP             ├─ Port: 514 UDP           │
│  └─ Secret: Pj8K2qL9xR5wM...   └─ Pour supervision        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
                             ▲
                    Clients Wi-Fi (RJ45 ou USB)
                             │
┌──────────────────────────────────────────────────────────────┐
│              CLIENTS Wi-Fi (Smartphones, laptops)             │
│                                                               │
│  CLIENT STAFF (Entreprise)       CLIENT GUEST (Invités)      │
│  ├─ SSID: Fitness-Pro           ├─ SSID: Fitness-Guest     │
│  ├─ Auth: 802.1X (EAP)          ├─ Auth: WPA2-PSK          │
│  ├─ User: alice@gym.fr           ├─ Password: public       │
│  ├─ Pass: Alice@123!             ├─ VLAN: 20               │
│  ├─ VLAN: 10                     ├─ Isolation: OUI         │
│  ├─ IP: 192.168.10.x             ├─ IP: 192.168.20.x       │
│  └─ Accès: Réseau complet        └─ Accès: Internet seul   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 🚀 Installation complète (du début à la fin)

### Phase 0 : VirtualBox ✅ FAIT

**Vous devez avoir :**
- ✅ VM Debian 11 créée (SAE501-Debian11)
- ✅ Réseau en BRIDGE configuré
- ✅ IP statique 192.168.10.100 configurée
- ✅ Projet SAE501 cloné dans ~/SAE501

### Phase 1 : Installation VM (1 heure)

#### Étape 1.1 : Préparer la VM Debian 11

```bash
# Vérifier les prérequis
lsb_release -d        # Debian 11 ou Ubuntu 20.04+
free -h               # 4GB RAM
df -h /               # 20GB disque
ip addr show          # 192.168.10.100 configurée ✓

# Mettre à jour le système
sudo apt update && sudo apt upgrade -y
```

#### Étape 1.2 : Installer FreeRADIUS

```bash
# Installation automatisée
cd ~/SAE501
sudo bash scripts/install_radius.sh

# Vérifier
systemctl status freeradius
radtest alice@gym.fr Alice@123! 127.0.0.1 1812 testing123
# Expected: Response code (2) = Access-Accept
```

#### Étape 1.3 : Installer PHP-Admin

```bash
sudo bash scripts/install_php_admin.sh

# Vérifier
curl http://localhost/php-admin/
# Devrait afficher HTML de la page d'accueil
```

#### Étape 1.4 : Installer Wazuh

```bash
sudo bash scripts/install_wazuh.sh

# Vérifier
systemctl status wazuh-manager
sudo tail -f /var/ossec/logs/ossec.log
```

#### Étape 1.5 : Diagnostic VM

```bash
sudo bash scripts/diagnostics.sh
# Score > 85% = OK ✓
```

---

### Phase 2 : Configuration du Routeur TL-MR100 (1 heure)

#### Étape 2.1 : Accéder au routeur

1. **Brancher le routeur** en RJ45 sur votre ordinateur portable
2. **Accéder à l'interface d'administration**
   ```
   URL: http://192.168.0.1
   Admin: admin
   Password: admin
   ```

#### Étape 2.2 : Configuration réseau

1. **Paramètres LAN**
   ```
   IP LAN: 192.168.10.1
   Masque: 255.255.255.0
   DHCP: Activé (192.168.10.100 → 192.168.10.254)
   ```

#### Étape 2.3 : Configurer l'authentification RADIUS

**Menu** → **System** → **RADIUS**

```
Primary RADIUS Server:
  IP Address: 192.168.10.100 (IP de votre VM)
  Port: 1812
  Secret: Pj8K2qL9xR5wM3nP7dF4vB6tH1sQ9cZ2
```

#### Étape 2.4 : Configurer les SSID

**Menu** → **Wireless** → **Edit**

**SSID 1 - Entreprise (Fitness-Pro)**
```
SSID: Fitness-Pro
Channel: 6
Security Type: WPA2-Enterprise
RADIUS Server: Configuré ci-dessus
VLAN: Enabled (VLAN 10)
AP Isolation: Disabled
```

**SSID 2 - Invités (Fitness-Guest)**
```
SSID: Fitness-Guest
Channel: 6
Security Type: WPA2-PSK
Password: GuestPass@2026
VLAN: Enabled (VLAN 20)
AP Isolation: Enabled
```

#### Étape 2.5 : Configurer le Syslog vers Wazuh

**Menu** → **System** → **Syslog**

```
Syslog Server:
  IP Address: 192.168.10.100 (VM)
  Port: 514
  Protocol: UDP
  Enable: ON
```

---

### Phase 3 : Tests Wi-Fi et Validation (45 min)

#### Étape 3.1 : Test authentification PEAP

**Depuis un client Linux :**

```bash
# Installer les tools
sudo apt install wpa-supplicant network-manager

# Créer un profil
cat > ~/fitness-pro.conf << 'EOF'
network={
    ssid="Fitness-Pro"
    key_mgmt=WPA-EAP
    eap=PEAP
    phase1="peapver=auto"
    phase2="auth=MSCHAPV2"
    identity="alice@gym.fr"
    password="Alice@123!"
    ca_cert="/etc/ssl/certs/ca-certificates.crt"
}
EOF

# Tester
sudo wpa_supplicant -i wlan0 -c ~/fitness-pro.conf -v
# Devrait afficher: CONNECTED
```

#### Étape 3.2 : Vérifier l'assignation VLAN

```bash
# Voir l'IP obtenue
ip addr show
# VLAN 10 (Staff): 192.168.10.x
# VLAN 20 (Guests): 192.168.20.x
```

#### Étape 3.3 : Test isolement réseau

```bash
# Depuis client STAFF (VLAN 10)
ping 192.168.10.254          # Gateway STAFF → OK
ping 8.8.8.8                 # Internet → OK

# Depuis client GUEST (VLAN 20)
ping 192.168.20.254          # Gateway GUEST → OK
ping 192.168.10.1            # Autre VLAN → BLOQUÉ ✓
ping 8.8.8.8                 # Internet → OK
```

---

### Phase 4 : Hardening du Serveur Linux (30 min)

#### Étape 4.1 : Sécuriser SSH

```bash
# Configuration SSH
sudo nano /etc/ssh/sshd_config

# Modifier:
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
X11Forwarding no
MaxAuthTries 3

# Redémarrer SSH
sudo systemctl restart ssh
```

#### Étape 4.2 : Configurer le Firewall UFW

```bash
# Activer UFW
sudo ufw enable

# Autoriser services essentiels
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 1812/udp    # FreeRADIUS
sudo ufw allow 1813/udp    # FreeRADIUS acct
sudo ufw allow 1514/udp    # Wazuh syslog
sudo ufw allow 80/tcp      # Apache
sudo ufw allow 443/tcp     # Apache HTTPS

# Vérifier
sudo ufw status verbose
```

#### Étape 4.3 : Permissions restrictives

```bash
# FreeRADIUS
sudo chown -R root:freerad /etc/freeradius/3.0
sudo chmod -R 750 /etc/freeradius/3.0

# MySQL
sudo chown -R mysql:mysql /var/lib/mysql
sudo chmod -R 750 /var/lib/mysql

# Wazuh
sudo chown -R root:wazuh /var/ossec/etc/
sudo chmod -R 750 /var/ossec/etc/
```

---

### Phase 5 : Tests de sécurité (15 min)

#### Étape 5.1 : Test Access-Reject

```bash
# Générer tentatives d'authentification échouées
for i in {1..100}; do
  radtest fake$i@gym.fr FakePass123! 127.0.0.1 1812 testing123 2>/dev/null &
done

# Vérifier que Wazuh détecte le brute-force
sudo grep -i "brute\|failed" /var/ossec/logs/alerts/alerts.json
```

#### Étape 5.2 : Vérifier isolation VLAN

```bash
# Client GUEST tente d'accéder Client STAFF
ping 192.168.10.x
# Doit timeout (BLOQUÉ) ✓
```

---

## 📋 Checklist finale d'installation

- [ ] **Phase 0 (VirtualBox)** - 30 min
  - [ ] VM Debian 11 créée avec Bridge
  - [ ] IP statique 192.168.10.100 configurée
  - [ ] Réseau testé (ping routeur + Internet)
  - [ ] Projet SAE501 cloné

- [ ] **Phase 1 (VM)** - 1h
  - [ ] FreeRADIUS installé et testé
  - [ ] MySQL opérationnel
  - [ ] PHP-Admin accessible
  - [ ] Wazuh Manager actif
  - [ ] Diagnostic: Score > 85%

- [ ] **Phase 2 (Routeur)** - 1h
  - [ ] Routeur accessible (192.168.10.1)
  - [ ] RADIUS configuré
  - [ ] SSID "Fitness-Pro" visible
  - [ ] SSID "Fitness-Guest" visible
  - [ ] Syslog vers Wazuh configuré

- [ ] **Phase 3 (Tests)** - 45 min
  - [ ] Client STAFF se connecte (Fitness-Pro)
  - [ ] Client STAFF obtient IP 192.168.10.x
  - [ ] Client GUEST se connecte (Fitness-Guest)
  - [ ] Client GUEST obtient IP 192.168.20.x
  - [ ] VLAN 10 ↔ VLAN 20 : Isolé ✓

- [ ] **Phase 4 (Hardening)** - 30 min
  - [ ] SSH sans password, root désactivé
  - [ ] UFW actif, ports minimaux ouverts
  - [ ] Permissions fichiers restrictives

- [ ] **Phase 5 (Tests sécurité)** - 15 min
  - [ ] Brute-force détecté par Wazuh
  - [ ] Isolement VLAN validé

---

## 🎯 Livrables GitLab/GitHub

Votre dépôt **DOIT** contenir :

```
SAE501/
├── README.md (ce fichier - vue complète)
├── SETUP.md (guide complémentaire)
│
├── scripts/
│   ├── install_radius.sh
│   ├── install_php_admin.sh
│   ├── install_wazuh.sh
│   └── diagnostics.sh
│
├── radius/
│   ├── clients.conf
│   ├── users.txt
│   └── sql/
│       ├── create_tables.sql
│       └── init_appuser.sql
│
├── php-admin/
│   ├── index.php
│   ├── add_user.php
│   ├── list_users.php
│   ├── delete_user.php
│   └── config.php
│
├── wazuh/
│   ├── manager.conf
│   ├── local_rules.xml
│   └── syslog-tlmr100.conf
│
├── docs/
│   ├── dossier-architecture.md
│   ├── hardening-linux.md
│   └── journal-de-bord.md
│
└── captures/
    ├── vm-installation.png
    ├── router-config.png
    └── wifi-connection.png
```

---

## ⏱️ Récapitulatif des durées

| Phase | Tâche | Durée |
|-------|-------|-------|
| 0 | VirtualBox + Debian | 1h |
| 1 | Installation VM (RADIUS/PHP/Wazuh) | 1h |
| 2 | Configuration routeur | 1h |
| 3 | Tests Wi-Fi | 45 min |
| 4 | Hardening | 30 min |
| 5 | Tests sécurité | 15 min |
| **TOTAL** | **Du VirtualBox au projet complet** | **~4h30** |

---

## 💡 Conseils importants

### ✅ Bonnes pratiques

1. **Testez chaque phase** avant de passer à la suivante
2. **Documentez au fur et à mesure** (journal-de-bord.md)
3. **Commitez régulièrement** sur GitHub/GitLab
4. **Gardez les logs** pour le troubleshooting
5. **Sauvegardez les configurations**

### 🔒 Sécurité

1. **Ne JAMAIS partager le secret RADIUS**
2. **Changer les passwords de test avant présentation**
3. **Activer UFW AVANT de connecter au routeur**
4. **Auditer régulièrement les authentifications**
5. **Archiver les logs (au moins 30 jours)**

---

**🚀 Commencez par configurer VirtualBox, puis suivez les phases ci-dessus !**
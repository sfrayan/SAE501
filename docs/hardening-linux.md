# Guide de Hardening Linux pour SAE501

## 📋 Table des Matières

1. [Introduction](#1-introduction)
2. [Prérequis](#2-prérequis)
3. [Mise à jour système](#3-mise-à-jour-système)
4. [Configuration UFW Firewall](#4-configuration-ufw-firewall)
5. [SSH Hardening](#5-ssh-hardening)
6. [Kernel Hardening](#6-kernel-hardening)
7. [Fail2Ban](#7-fail2ban)
8. [Auditd](#8-auditd)
9. [Sauvegardes et Maintenance](#9-sauvegardes-et-maintenance)

---

## 1. Introduction

Ce guide décrit les mesures de sécurisation (hardening) appliquées au système Linux pour le projet SAE501. L'objectif est de renforcer la sécurité du serveur hébergeant FreeRADIUS, MySQL, Apache et Wazuh.

### Objectifs du hardening

- 🔒 Minimiser la surface d'attaque
- 🛡️ Protéger contre les attaques par force brute
- 📊 Améliorer la traçabilité des actions
- 🚫 Bloquer les accès non autorisés
- ⚡ Maintenir les performances système

---

## 2. Prérequis

### Vérifications initiales

```bash
# Vérifier version OS
lsb_release -a

# Vérifier droits root
whoami

# Vérifier espace disque
df -h

# Vérifier mémoire
free -h
```

### Installation des outils de base

```bash
# Mettre à jour les dépôts
sudo apt update

# Installer les outils essentiels
sudo apt install -y \
    ufw \
    fail2ban \
    auditd \
    aide \
    unattended-upgrades \
    apt-listchanges
```

---

## 3. Mise à jour système

### 3.1 Mise à jour manuelle

```bash
# Mettre à jour la liste des paquets
sudo apt update

# Mettre à jour tous les paquets
sudo apt upgrade -y

# Nettoyer les paquets obsolètes
sudo apt autoremove -y
sudo apt autoclean
```

### 3.2 Mises à jour automatiques

```bash
# Configuration des mises à jour automatiques de sécurité
sudo dpkg-reconfigure -plow unattended-upgrades

# Fichier de configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

**Configuration recommandée** :

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::Automatic-Reboot "false";
```

---

## 4. Configuration UFW Firewall

### 4.1 Installation et activation

```bash
# Installer UFW si nécessaire
sudo apt install -y ufw

# Réinitialiser UFW (en cas de reconfiguration)
sudo ufw --force reset

# Politique par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed
```

### 4.2 Règles essentielles

```bash
# SSH (important : autoriser AVANT d'activer UFW)
sudo ufw allow 22/tcp comment "SSH"

# HTTP/HTTPS
sudo ufw allow 80/tcp comment "HTTP"
sudo ufw allow 443/tcp comment "HTTPS"

# FreeRADIUS
sudo ufw allow 1812/udp comment "RADIUS Authentication"
sudo ufw allow 1813/udp comment "RADIUS Accounting"

# MySQL (localhost uniquement)
sudo ufw allow from 127.0.0.1 to 127.0.0.1 port 3306 comment "MySQL local"

# Wazuh Dashboard
sudo ufw allow 5601/tcp comment "Wazuh Dashboard"

# Activer UFW
sudo ufw --force enable
```

### 4.3 Vérification

```bash
# État détaillé
sudo ufw status verbose

# Liste numérotée des règles
sudo ufw status numbered

# Logs UFW
sudo tail -f /var/log/ufw.log
```

### 4.4 Gestion des règles

```bash
# Supprimer une règle par numéro
sudo ufw delete [numéro]

# Désactiver temporairement
sudo ufw disable

# Réactiver
sudo ufw enable
```

---

## 5. SSH Hardening

### 5.1 Sauvegarde de la configuration

```bash
# Toujours faire une sauvegarde avant modification
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

### 5.2 Configuration sécurisée

Fichier `/etc/ssh/sshd_config` :

```bash
# SAE501 - SSH Hardened Configuration

# Port et protocole
Port 22
Protocol 2

# Authentification
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Limites
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60

# Fonctionnalités désactivées
X11Forwarding no
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no

# Keep-alive
ClientAliveInterval 300
ClientAliveCountMax 2

# Cryptographie moderne
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,diffie-hellman-group-exchange-sha256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Banner
Banner /etc/issue.net
```

### 5.3 Créer un banner

```bash
sudo nano /etc/issue.net
```

Contenu :

```
###############################################################
#                   ACCÈS AUTORISÉ UNIQUEMENT                #
#                                                             #
# L'accès non autorisé à ce système est interdit et sera     #
# poursuivi conformément à la loi.                            #
###############################################################
```

### 5.4 Redémarrer SSH

```bash
# Tester la configuration
sudo sshd -t

# Si OK, redémarrer
sudo systemctl restart sshd

# Vérifier le statut
sudo systemctl status sshd
```

### 5.5 Test de connexion

**Important** : Toujours tester la connexion SSH dans une nouvelle session avant de fermer la session actuelle !

```bash
# Depuis une autre machine
ssh utilisateur@ip_serveur

# Vérifier les logs en cas d'échec
sudo tail -f /var/log/auth.log
```

---

## 6. Kernel Hardening

### 6.1 Création du fichier de configuration

```bash
sudo nano /etc/sysctl.d/99-sae501-hardening.conf
```

### 6.2 Paramètres recommandés

```bash
# SAE501 - Kernel Hardening

# ============================================================================
# PROTECTION KERNEL
# ============================================================================

# Cacher les adresses kernel
kernel.kptr_restrict = 2

# Restreindre dmesg aux utilisateurs privilégiés
kernel.dmesg_restrict = 1

# Niveau de log kernel
kernel.printk = 3 3 3 3

# Désactiver BPF non privilégié
kernel.unprivileged_bpf_disabled = 1

# Désactiver user namespaces non privilégiés
kernel.unprivileged_userns_clone = 0

# Protection contre ptrace
kernel.yama.ptrace_scope = 2

# ============================================================================
# CORE DUMPS
# ============================================================================

# Core dumps avec PID
kernel.core_uses_pid = 1

# Désactiver les core dumps pour les programmes SUID
fs.suid_dumpable = 0

# ============================================================================
# ASLR (Address Space Layout Randomization)
# ============================================================================

# ASLR complet
kernel.randomize_va_space = 2

# ============================================================================
# SÉCURITÉ RÉSEAU - IPv4
# ============================================================================

# Activer le filtrage de chemin inverse (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Désactiver le routage de source
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Désactiver les redirections ICMP
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0

# Ne pas envoyer de redirections ICMP
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Logger les paquets suspects (martiens)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignorer les broadcasts ICMP
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignorer les réponses ICMP erronées
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Protection contre les attaques SYN flood
net.ipv4.tcp_syncookies = 1

# Activer les timestamps TCP
net.ipv4.tcp_timestamps = 1

# Augmenter la file d'attente SYN
net.ipv4.tcp_max_syn_backlog = 4096

# Réduire le temps de FIN
net.ipv4.tcp_fin_timeout = 15

# ============================================================================
# SÉCURITÉ RÉSEAU - IPv6
# ============================================================================

# Garder IPv6 actif (nécessaire pour certains services)
net.ipv6.conf.all.disable_ipv6 = 0

# Désactiver le routage de source IPv6
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Désactiver les redirections IPv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Désactiver le forwarding IPv6
net.ipv6.conf.all.forwarding = 0

# ============================================================================
# SYSTÈME DE FICHIERS
# ============================================================================

# Protection des liens symboliques
fs.protected_symlinks = 1

# Protection des liens durs
fs.protected_hardlinks = 1

# Protection des fichiers réguliers
fs.protected_regular = 2

# Protection des FIFOs
fs.protected_fifos = 2

# ============================================================================
# AUTRES PARAMÈTRES
# ============================================================================

# Augmenter le PID max
kernel.pid_max = 2097152

# Restreindre les événements perf
kernel.perf_event_paranoid = 3

# Désactiver magic SysRq
kernel.sysrq = 0

# Panic après 60 secondes
kernel.panic = 60

# Ne pas paniquer sur oops
kernel.panic_on_oops = 0
```

### 6.3 Application des paramètres

```bash
# Appliquer immédiatement
sudo sysctl -p /etc/sysctl.d/99-sae501-hardening.conf

# Vérifier un paramètre spécifique
sudo sysctl kernel.kptr_restrict

# Lister tous les paramètres actifs
sudo sysctl -a | grep -E "(kernel|net)" | less
```

### 6.4 Vérification persistance

```bash
# Vérifier que le fichier sera chargé au démarrage
ls -l /etc/sysctl.d/99-sae501-hardening.conf

# Tester le rechargement
sudo sysctl --system
```

---

## 7. Fail2Ban

### 7.1 Installation

```bash
sudo apt install -y fail2ban
```

### 7.2 Configuration

Créer `/etc/fail2ban/jail.local` :

```bash
[DEFAULT]
# Durée de bannissement (secondes)
bantime = 3600

# Fenêtre de temps pour comptabiliser les tentatives (secondes)
findtime = 600

# Nombre de tentatives avant bannissement
maxretry = 5

# Email de notification
destemail = root@localhost
sender = root@localhost

# Action par défaut (ban + notification email)
action = %(action_mwl)s

# IPs à ne jamais bannir
ignoreip = 127.0.0.1/8 ::1

# ============================================================================
# PROTECTION SSH
# ============================================================================

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[sshd-ddos]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 10
findtime = 600
bantime = 3600

# ============================================================================
# RÉCIDIVE (bannissement long)
# ============================================================================

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
bantime = 604800  # 7 jours
findtime = 86400  # 24 heures
maxretry = 5

# ============================================================================
# PROTECTION APACHE
# ============================================================================

[apache-auth]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 5

[apache-badbots]
enabled = true
port = http,https
logpath = /var/log/apache2/access.log
maxretry = 3
bantime = 7200

[apache-noscript]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 5

[apache-overflows]
enabled = true
port = http,https
logpath = /var/log/apache2/error.log
maxretry = 2
bantime = 7200
```

### 7.3 Gestion Fail2Ban

```bash
# Démarrer et activer
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Vérifier le statut
sudo systemctl status fail2ban

# Voir toutes les jails actives
sudo fail2ban-client status

# Voir les détails d'une jail spécifique
sudo fail2ban-client status sshd

# Débannir une IP
sudo fail2ban-client set sshd unbanip 192.168.1.100

# Bannir manuellement une IP
sudo fail2ban-client set sshd banip 192.168.1.100

# Recharger la configuration
sudo fail2ban-client reload
```

### 7.4 Monitoring

```bash
# Voir les bans récents
sudo tail -f /var/log/fail2ban.log

# Statistiques par jail
sudo fail2ban-client status | grep "Jail list"

# Logs détaillés
sudo grep "Ban" /var/log/fail2ban.log | tail -20
```

---

## 8. Auditd

### 8.1 Installation

```bash
sudo apt install -y auditd audispd-plugins
```

### 8.2 Règles d'audit

Créer `/etc/audit/rules.d/sae501.rules` :

```bash
# SAE501 - Règles d'audit système

# Supprimer toutes les règles existantes
-D

# Buffer size (augmenté pour systèmes chargés)
-b 8192

# Failure mode (1 = continuer en cas d'erreur)
-f 1

# ============================================================================
# SURVEILLANCE DES COMMANDES EXÉCUTÉES
# ============================================================================

# Toutes les exécutions de programmes
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec

# ============================================================================
# SURVEILLANCE DES FICHIERS CRITIQUES
# ============================================================================

# Configuration sudo
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# Logs d'authentification
-w /var/log/auth.log -p wa -k auth_log_changes

# Configuration SSH
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# Configuration MySQL
-w /etc/mysql/ -p wa -k mysql_config_changes

# Configuration FreeRADIUS
-w /etc/freeradius/ -p wa -k radius_config_changes

# Configuration Apache
-w /etc/apache2/ -p wa -k apache_config_changes

# ============================================================================
# SURVEILLANCE UTILISATEURS ET GROUPES
# ============================================================================

-w /etc/group -p wa -k group_modifications
-w /etc/passwd -p wa -k passwd_modifications
-w /etc/gshadow -p wa -k gshadow_modifications
-w /etc/shadow -p wa -k shadow_modifications
-w /etc/security/opasswd -p wa -k password_history

# ============================================================================
# SURVEILLANCE RÉSEAU
# ============================================================================

# Modifications hostname/domainname
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k network_modifications

# Fichiers réseau
-w /etc/hosts -p wa -k network_modifications
-w /etc/network/ -p wa -k network_modifications

# ============================================================================
# SURVEILLANCE DES MONTAGES
# ============================================================================

-a always,exit -F arch=b64 -S mount -S umount2 -k mounts

# ============================================================================
# SURVEILLANCE BINAIRES SYSTÈME
# ============================================================================

-w /bin/ -p wa -k binaries
-w /sbin/ -p wa -k binaries
-w /usr/bin/ -p wa -k binaries
-w /usr/sbin/ -p wa -k binaries

# ============================================================================
# RÈGLE FINALE - RENDRE IMMUTABLE
# ============================================================================

# Rendre la configuration immutable (nécessite reboot pour modifier)
-e 2
```

### 8.3 Activation et gestion

```bash
# Charger les règles
sudo augenrules --load

# Redémarrer auditd
sudo systemctl restart auditd

# Vérifier le statut
sudo systemctl status auditd

# Lister les règles actives
sudo auditctl -l

# Statistiques
sudo auditctl -s
```

### 8.4 Recherche dans les logs

```bash
# Rechercher toutes les exécutions aujourd'hui
sudo ausearch -k exec -ts today

# Rechercher les modifications de sudoers
sudo ausearch -k sudoers_changes -ts today

# Rechercher par utilisateur
sudo ausearch -ua username

# Rechercher les tentatives d'accès à un fichier
sudo ausearch -f /etc/shadow -ts today

# Rechercher par type d'événement
sudo ausearch -m USER_LOGIN -ts today

# Formatage lisible
sudo ausearch -k exec -ts today --interpret | less

# Dernières 50 entrées
sudo ausearch -k exec | tail -50
```

### 8.5 Rapports audit

```bash
# Rapport complet d'activité
sudo aureport

# Rapport des exécutables
sudo aureport -x

# Rapport des fichiers
sudo aureport -f

# Rapport des utilisateurs
sudo aureport -u

# Rapport des anomalies
sudo aureport -a

# Rapport personnalisé sur une période
sudo aureport --start 01/31/2026 00:00:00 --end 01/31/2026 23:59:59
```

---

## 9. Sauvegardes et Maintenance

### 9.1 Sauvegardes automatiques

```bash
# Sauvegarder base RADIUS
mysqldump -u root -p radius > backup_radius_$(date +%Y%m%d).sql

# Sauvegarder configuration Wazuh
tar -czf backup_wazuh_$(date +%Y%m%d).tar.gz \
  /var/ossec/etc/ossec.conf \
  /var/ossec/ruleset/ \
  /var/ossec/logs/

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

# Vérifier espace disque
df -h

# Vérifier charge système
uptime
top -n 1 -b | head -20

# Vérifier erreurs kernel
sudo dmesg | grep -i error | tail -20
```

### 9.4 Checklist de sécurité hebdomadaire

```bash
#!/bin/bash
# Script de vérification hebdomadaire

echo "=== Vérification Sécurité Hebdomadaire ==="
echo ""

echo "1. Mises à jour disponibles:"
apt list --upgradable
echo ""

echo "2. Tentatives SSH échouées (derniers 7 jours):"
grep "Failed password" /var/log/auth.log | wc -l
echo ""

echo "3. IPs bannies actuellement:"
sudo fail2ban-client status sshd | grep "Currently banned"
echo ""

echo "4. Espace disque:"
df -h | grep -E '(Filesystem|/dev/)'
echo ""

echo "5. Services critiques:"
for service in ssh mysql apache2 freeradius wazuh-manager fail2ban auditd ufw; do
  status=$(systemctl is-active $service 2>/dev/null || echo "non installé")
  echo "  - $service: $status"
done
echo ""

echo "6. Dernières modifications sudo:"
sudo ausearch -k sudoers_changes -ts week-ago 2>/dev/null | grep -c "type="
echo ""

echo "=== Fin de la vérification ==="
```

### 9.5 Rotation des logs

```bash
# Configuration logrotate pour fail2ban
sudo nano /etc/logrotate.d/fail2ban
```

Contenu :

```
/var/log/fail2ban.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        fail2ban-client flushlogs >/dev/null 2>&1 || true
    endscript
}
```

---

## 🎯 Conclusion

Ce guide couvre les mesures essentielles de hardening pour sécuriser votre serveur SAE501. Les configurations présentées offrent un équilibre entre sécurité et utilisabilité.

### Points clés

✅ **Firewall** : UFW filtrage actif  
✅ **SSH** : Authentification durcie  
✅ **Kernel** : Paramètres sécurisés  
✅ **Anti-bruteforce** : Fail2Ban actif  
✅ **Audit** : Traçabilité complète  
✅ **Maintenance** : Automatisation  

### Prochaines étapes

1. Tester régulièrement la configuration
2. Maintenir les sauvegardes à jour
3. Surveiller les logs quotidiennement
4. Appliquer les mises à jour de sécurité
5. Revoir la configuration trimestriellement

---

**Documentation SAE501** | Version 2.0 | Janvier 2026

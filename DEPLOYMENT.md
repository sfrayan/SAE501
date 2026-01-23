# SAE501 - Guide de déploiement complet

## Installation d'un domaine à l'autre

Ce guide permet de déployer SAE501 sur n'importe quel système Debian 12+/Ubuntu 22.04+ en ~15-20 minutes.

## Pré-requis

```bash
# Vérifier la distro
lsb_release -a

# Vérifier l'accès root
sudo whoami  # Doit afficher: root
```

## Installation rapide (5 étapes)

### Étape 0: Préparation

```bash
# Clone le dossier
git clone https://github.com/sfrayan/SAE501.git
cd SAE501

# Rendre les scripts exécutables
chmod +x scripts/*.sh tests/*.sh

# Vérifier les permissions
ls -la scripts/
```

### Étape 1: Installation de base (2 min)

```bash
echo "[1/5] Installation de base..."
sudo bash scripts/install_base.sh

# Suivre les messages. Le script:
# - Met à jour le système
# - Installe les dépendances essentielles
# - Configure UFW firewall
# - Crée l'utilisateur sae501
# - Configure la journalisation
```

### Étape 2: Installation MariaDB (2 min)

```bash
echo "[2/5] Installation MariaDB..."
sudo bash scripts/install_mysql.sh

# Le script:
# - Installe et sécurise MariaDB
# - Crée la base 'radius'
# - Crée les utilisateurs radiususer et sae501_php
# - Import le schéma RADIUS
# - Crée les tables d'audit
#
# OUTPUT: Sauvegarde les identifiants générés
# Fichier: /opt/sae501/secrets/db.env
```

### Étape 3: Installation RADIUS (3 min)

```bash
echo "[3/5] Installation FreeRADIUS..."
sudo bash scripts/install_radius.sh

# Le script:
# - Installe FreeRADIUS
# - Configure PEAP-MSCHAPv2
# - Configure le module SQL
# - Génère le certificat serveur
# - Teste la connexion
#
# Logs: /var/log/sae501/radius/auth.log
```

### Étape 4: Installation Wazuh (5 min, optionnel)

```bash
echo "[4/5] Installation Wazuh Manager..."
sudo bash scripts/install_wazuh.sh

# Le script:
# - Installe Wazuh Manager
# - Configure l'agent local
# - Configure le listener syslog
# - Configure les décodeurs pour RADIUS et TL-MR100
#
# Accès: https://localhost:5601
```

### Étape 5: Vérification (1 min)

```bash
echo "[5/5] Vérification..."
sudo bash /opt/sae501/scripts/health_check.sh

# Doit afficher:
# - RADIUS: running
# - MariaDB: running
# - PHP-FPM: running
# - Wazuh: running (si installé)
```

## Accés aux interfaces

### Interface PHP-Admin

```
URL: http://localhost/admin/
Utilisateur: admin
Mot de passe: admin123 (CHANGER IMMEDIATEMMENT!)
```

### Wazuh Dashboard

```
URL: https://localhost:5601
Utilisateur: admin
Mot de passe: [généré par Wazuh]
```

### Tests RADIUS

```bash
# Tester PEAP-MSCHAPv2
sudo bash tests/test_peap.sh

# Doit afficher: "Access-Accept"
```

## Configuration du routeur TL-MR100

### Accéder à l'interface du routeur

```
URL: http://192.168.0.1
Utilisateur: admin
Mot de passe: admin (par défaut)
```

### Configurer RADIUS

1. **Interface** > **WLAN Settings** > **Enterprise**
2. **RADIUS Server Settings**:
   - Server IP: [IP_DU_SERVEUR_SAE501]
   - Port: 1812
   - Secret: [Même valeur dans clients.conf]
3. **WLAN SSID Name**: "Entreprise"
4. **Security**: "WPA2-Enterprise (PEAP-MSCHAPv2)"
5. **Save** et Redémarrer

### Valider la configuration

```bash
# Vérifier que le routeur envoie des requêtes
sudo tail -f /var/log/sae501/radius/auth.log

# Doit afficher des requêtes d'authentification
```

## Tests de connexion Wi-Fi

### Depuis un client Linux

```bash
# Scanner les réseaux
sudo nmcli device wifi list

# Connecter au SSID Entreprise
sudo nmcli connection add type wifi con-name SAE501 ssid Entreprise
sudo nmcli connection modify SAE501 wifi-sec.key-mgmt wpa-eap
sudo nmcli connection modify SAE501 802-1x.eap peap
sudo nmcli connection modify SAE501 802-1x.phase2-auth mschapv2
sudo nmcli connection modify SAE501 802-1x.identity testuser
sudo nmcli connection modify SAE501 802-1x.password password123

# Activer
sudo nmcli connection up SAE501

# Vérifier
ip addr show
```

### Depuis un client Windows

1. **Paramètres** > **Réseau** > **WiFi** > **Gérer les réseaux connus**
2. **Ajouter un réseau**:
   - SSID: "Entreprise"
   - Type de sécurité: WPA3/WPA2-Enterprise
   - Méthode EAP: PEAP
   - Authentification de phase 2: MSCHAPv2
   - Nom d'utilisateur: testuser
   - Mot de passe: password123
3. **Connecter**

### Depuis un client macOS

1. **Paramètres système** > **Réseau** > **WiFi**
2. **Sélectionner** "Entreprise"
3. **Configurer**:
   - Méthode 802.1X: PEAP
   - ID utilisateur: testuser
   - Mot de passe: password123
   - Phase 2: MSCHAPv2

## Commandes utiles après installation

### Ajouter un utilisateur

```bash
# Interactif
sudo mysql -u radiususer -p radius

INSERT INTO radcheck (username, attribute, op, value) 
VALUES ('employe1', 'User-Password', ':=', 'SecurePass@2024');
```

### Vérifier l'état

```bash
# Tous les services
sudo systemctl status freeradius mariadb wazuh-manager

# Ou utiliser le health check
bash /opt/sae501/scripts/health_check.sh
```

### Consulter les logs

```bash
# RADIUS authentifications
sudo tail -50 /var/log/sae501/radius/auth.log

# Erreurs RADIUS
sudo tail -50 /var/log/sae501/radius/reply.log

# Audit admin
sudo tail -50 /var/log/sae501/php_admin_audit.log

# Système général
journalctl -f
```

### Redémarrer les services

```bash
# Tous
sudo systemctl restart freeradius mariadb wazuh-manager nginx php8.2-fpm

# Individuellement
sudo systemctl restart freeradius
sudo systemctl restart mariadb
sudo systemctl restart wazuh-manager
```

## Troubleshooting

### RADIUS ne répond pas

```bash
# Vérifier le service
sudo systemctl status freeradius

# Relancer en debug
sudo radiusd -X

# Vérifier le port
sudo netstat -ulpn | grep 1812

# Vérifier la configuration
sudo radiusd -C
```

### Accés MariaDB impossible

```bash
# Tester la connexion
mysql -u radiususer -p -h localhost radius -e "SELECT 1;"

# Vérifier les droits
sudo mysql -u root radius -e "SHOW GRANTS FOR 'radiususer'@'localhost';"

# Recharger les permissions
sudo mysql -u root -e "FLUSH PRIVILEGES;"
```

### Interface PHP non accessible

```bash
# Vérifier Nginx
sudo systemctl status nginx
sudo nginx -t  # Vérifier la syntaxe

# Vérifier PHP-FPM
sudo systemctl status php8.2-fpm
sudo tail -f /var/log/php8.2-fpm.log

# Vérifier les logs Nginx
sudo tail -f /var/log/nginx/error.log
```

### Wi-Fi n'authentifie pas

```bash
# Vérifier les logs d'auth
sudo tail -f /var/log/sae501/radius/auth.log

# Vérifier les utilisateurs
mysql -u radiususer -p radius -e "SELECT * FROM radcheck;"

# Vérifier le certificat PEAP
openssl x509 -in /etc/radius/certs/server.crt -noout -text
```

## Performance

### Métriques attendues

- **Temps de réponse auth**: < 100ms
- **Connexions simultanées**: 1000+
- **Authentifications/sec**: 100+
- **Mémoire**: ~500MB (idle)
- **CPU**: < 5% (idle)

### Optimisation

```bash
# Augmenter les connexions MariaDB
sudo mysql -u root -e "SET GLOBAL max_connections = 1000;"

# Augmenter les worker RADIUS
sudo sed -i 's/^#max_servers = .*/max_servers = 256/' /etc/freeradius/3.0/radiusd.conf

# Redémarrer
sudo systemctl restart freeradius mariadb
```

## Maintenance régulière

### Quotidienne
```bash
# Vérifier les alertes Wazuh
grep WARN /var/ossec/logs/alerts/alerts.log
```

### Hebdomadaire
```bash
# Backup de la base
mysqldump -u root radius | gzip > backup_radius_$(date +%F).sql.gz

# Nettoyer les vieux logs
find /var/log/sae501 -name "*.log" -mtime +30 -delete
```

### Mensuelle
```bash
# Patch du système
sudo apt update && sudo apt upgrade -y

# Vérifier les certificats
openssl x509 -in /etc/radius/certs/server.crt -noout -enddate

# Vérifier les utilisateurs inutilisés
mysql -u radius radius -e "SELECT username, last_login FROM user_status WHERE last_login < DATE_SUB(NOW(), INTERVAL 90 DAY);"
```

## Support

Pour les problèmes:
1. Consulter `/docs/SECURITY.md`
2. Vérifier les logs: `tail -f /var/log/sae501/*`
3. Exécuter: `bash /opt/sae501/scripts/health_check.sh`
4. Voir le journal: `journalctl -f`

---

**Dernière mise à jour**: 23 janvier 2026
**Version**: 1.0.0

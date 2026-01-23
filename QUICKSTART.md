# SAE501 - Guide de démarrage rapide

## Installation en une commande

Pour une installation complète et automatisée de tous les services :

```bash
sudo bash scripts/install_all.sh
```

Ce script installe automatiquement :
- ✅ FreeRADIUS avec MySQL
- ✅ PHP-Admin (interface graphique de gestion)
- ✅ Wazuh (monitoring et sécurité)
- ✅ Hardening du système

**Durée estimée:** 15-20 minutes

---

## Après l'installation

### 1. Accéder aux interfaces

**PHP-Admin (Gestion RADIUS)**
- URL: `http://localhost/admin`
- Utilisateur: `admin`
- Mot de passe: `Admin@Secure123!` (CHANGEZ-LE)

**Wazuh Dashboard**
- URL: `http://localhost:5601`
- Utilisateur: `admin`
- Mot de passe: `SecurePassword123!` (CHANGEZ-LE)

**FreeRADIUS Stats**
- Port: 1812 (authentification)
- Port: 1813 (accounting)

### 2. Premières configurations obligatoires

**Changez les mots de passe par défaut:**

```bash
# MySQL root
sudo mysql -u root -p  # Enter: MySQL@Root123!
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NouveauMotDePasse';

# PHP-Admin
# Allez dans PHP-Admin > Paramétrages > Changer le mot de passe

# Wazuh
# Allez dans Wazuh > Profile > Changer le mot de passe
```

**Configurez RADIUS:**

1. Accédez à PHP-Admin
2. Allez dans "Paramétrages"
3. Configurez le secret RADIUS et l'IP NAS

### 3. Tests de connectivité

```bash
# Vérifier l'état des services
sudo systemctl status radiusd
sudo systemctl status php-fpm
sudo systemctl status mysql
sudo systemctl status wazuh-manager

# Exécuter les diagnostics complets
bash scripts/diagnostics.sh

# Tester RADIUS avec radtest
radtest utilisateur mot_de_passe 127.0.0.1 0 secret_partage
```

### 4. Configuration du Wi-Fi

**Sur votre routeur:**

1. Allez dans les paramétrages de sécurité Wi-Fi
2. Sélectionnez le type d'authentification: **Enterprise (WPA-Enterprise)**
3. Choisissez le protocole: **PEAP ou EAP-TLS**
4. Adresse du serveur RADIUS: Adresse IP de votre VM
5. Port: **1812**
6. Secret partagé: Le secret que vous avez configuré en PHP-Admin

### 5. Surveiller les logs

```bash
# Logs RADIUS
sudo tail -f /var/log/freeradius/radius.log

# Logs PHP-Admin
sudo tail -f /var/log/apache2/access.log

# Logs Wazuh
sudo tail -f /var/ossec/logs/ossec.log

# Tous les logs dans PHP-Admin
# Admin > Logs d'audit
```

---

## Installation personnalisée

Si vous voulez installer les services séparément :

```bash
# Installation RADIUS seule
sudo bash scripts/install_radius.sh

# Installation PHP-Admin seule
sudo bash scripts/install_php_admin.sh

# Installation Wazuh seule
sudo bash scripts/install_wazuh.sh

# Hardening du système seule
sudo bash scripts/install_hardening.sh
```

---

## Dépannage

### RADIUS ne démarre pas
```bash
sudo systemctl status radiusd -l
sudo /usr/sbin/radiusd -X  # Mode debug
```

### PHP-Admin inaccessible
```bash
sudo systemctl status apache2
sudo systemctl status php-fpm
sudo a2enmod php8.2
sudo systemctl restart apache2
```

### Connexion Wi-Fi échoue
```bash
# Vérifier les logs RADIUS
sudo tail -f /var/log/freeradius/radius.log

# Test manuel
radtest user_test password123 localhost 0 shared_secret
```

### Wazuh ne répond pas
```bash
sudo systemctl restart wazuh-manager
sudo systemctl restart elasticsearch
```

---

## Sécurité en production

**Avant de mettre en production, effectuez:**

1. ✅ Changez TOUS les mots de passe par défaut
2. ✅ Activez SSL/TLS pour HTTPS
3. ✅ Configurez le pare-feu pour limiter l'accès
4. ✅ Activez 2FA pour PHP-Admin
5. ✅ Configurez les certificats SSL/TLS
6. ✅ Mettez à jour tous les paquets système
7. ✅ Sauvegardez régulièrement la base de données

---

## Documentation complète

Pour plus de détails, consultez:
- `docs/dossier-architecture.md` - Architecture générale
- `docs/hardening-linux.md` - Hardening du système
- `docs/journal-de-bord.md` - Journal de développement
- `README.md` - Documentation complète

---

## Support

En cas de problème:
1. Vérifiez les logs: `bash scripts/diagnostics.sh`
2. Consultez la documentation
3. Vérifiez les permissions de fichiers
4. Relancez les services: `sudo systemctl restart radiusd`

---

**Créé avec ❤ pour SAE501**

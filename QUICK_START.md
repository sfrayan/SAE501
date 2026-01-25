# 🚀 SAE501 - Guide de Démarrage Rapide

## 🎫 Situation Actuelle

Vous avez une **VM Debian 11** avec:
- ✅ **MySQL**: Installé et fonctionnel
- ✅ **PHP-Admin**: Interface web fonctionne
- ⚠️ **FreeRADIUS**: Service installé mais besoin de correction
- ⚠️ **Configuration RADIUS**: Clients non configurés correctement

---

## 🍀 Dernières Corrections Apportées

J'ai corrigé dans le repo:

1. 🔧 **install_radius.sh** - Configuration correcte des clients localhost
2. 🔧 **install_all.sh** - Vérification et redémarrage FreeRADIUS
3. ✨ **fix_radius.sh** - Script de diagnostic/correction

---

## 📄 Marche à Suivre

### Étape 1: Mettre à jour le code

```bash
cd /opt/SAE501
git pull
```

### Étape 2: Lancer la correction FreeRADIUS

```bash
sudo bash scripts/fix_radius.sh
```

Ce script va:
- ✅ Vérifier l'état de FreeRADIUS
- ✅ Ajouter la configuration des clients (localhost, 127.0.0.1)
- ✅ Corriger les permissions
- ✅ Redémarrer le service
- ✅ Tester l'authentification

### Étape 3: Vérifier que tout fonctionne

```bash
# Test RADIUS
radtest wifi_user password123 localhost 1812 testing123

# Vous devriez voir:
# Received Access-Accept Id ... from 127.0.0.1:1812
```

### Étape 4: Vérifier l'interface web

```
URL: http://localhost/php-admin/
Login: admin / Admin@Secure123!
```

---

## 📚 Alternative: Relancer Installation Complète

Si vous voulez recommencer à zéro:

```bash
cd /opt/SAE501
git pull
sudo bash scripts/install_all.sh
```

**Durée:** 15-20 minutes

---

## 🔍 Diagnostic

Pour vérifier l'état complet du système:

```bash
sudo bash scripts/diagnostics.sh
```

Affiche:
- État des services
- Ports en écoute
- Connexion base de données
- Accès PHP-Admin
- Test FreeRADIUS

---

## 🗐 Commandes Utiles

### Vérifier FreeRADIUS

```bash
# État du service
sudo systemctl status freeradius

# Redémarrer
sudo systemctl restart freeradius

# Voir les logs
sudo tail -f /var/log/freeradius/radius.log

# Test RADIUS
radtest wifi_user password123 localhost 1812 testing123
```

### Vérifier MySQL

```bash
# Connexion
mysql -u root

# Vérifier utilisateur test
SELECT * FROM radius.radcheck WHERE username='wifi_user';
```

### Vérifier Apache/PHP

```bash
# État
sudo systemctl status apache2

# Redémarrer
sudo systemctl restart apache2

# Voir PHP-Admin
ls -la /var/www/html/php-admin/
```

---

## 📄 Identifiants

```
PHP-Admin
  URL: http://localhost/php-admin/
  Login: admin
  Password: Admin@Secure123!

Test Wi-Fi
  User: wifi_user
  Password: password123

RADIUS
  Server: localhost
  Port: 1812 (UDP)
  Secret: testing123

MySQL
  User: radiususer
  Database: radius
```

---

## 💺 Support

### Si FreeRADIUS ne répond pas:

1. Vérifier le service:
   ```bash
   sudo systemctl status freeradius
   ```

2. Relancer:
   ```bash
   sudo systemctl restart freeradius
   sleep 3
   ```

3. Vérifier configuration:
   ```bash
   grep -n "client localhost" /etc/freeradius/3.0/clients.conf
   ```

4. Utiliser le script de correction:
   ```bash
   sudo bash scripts/fix_radius.sh
   ```

### Si PHP-Admin ne charge pas:

1. Vérifier Apache:
   ```bash
   sudo systemctl restart apache2
   ```

2. Vérifier permissions:
   ```bash
   ls -la /var/www/html/php-admin/
   ```

3. Vérifier PHP:
   ```bash
   php --version
   ```

---

## 🌟 Présumé

Après avoir suivi ces étapes:

✅ **FreeRADIUS** fonctionne et écoute sur :1812  
✅ **PHP-Admin** est accessible et opérationnel  
✅ **Utilisateur test** peut s'authentifier  
✅ **Base données** est configurée  

**Votre système SAE501 est prêt! 🚀**

---

**Dernière mise à jour:** 2026-01-25 15:05

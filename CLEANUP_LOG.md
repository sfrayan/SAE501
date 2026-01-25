# CLEANUP_LOG - Modifications effectuées

## Date: 25 Janvier 2026

### Modifications apportées:

#### 1. ✅ CORRIGÉ: install_all.sh
- **Problème**: Le script appelait `install_mysql.sh` qui existait mais n'était pas cohérent
- **Correction**: 
  - Redéfini la structure pour MySQL/MariaDB (avec MySQL/MariaDB au lieu d'une install séparée)
  - Optimisé pour Debian 11 avec interface NAT VirtualBox
  - Ajout des vérifications de services (Apache2, FreeRADIUS)
  - Clarifié les identifiants et les chemins d'accès
  - Adapté pour VM sans accès routeur TP-Link initial

#### 2. 📁 Dossiers NON supprimés (ils contiennent du code installé):
- `php-admin/` - Géré par install_php_admin.sh
- `radius/` - Géré par install_radius.sh  
- `wazuh/` - Géré par install_wazuh.sh
- `docs/` - Conservé volontairement (demande utilisateur)

**Raison**: Ces dossiers contiennent des fichiers de configuration utiles même si les scripts les créent aussi.

### 🔧 Services cohérents:

1. **MySQL/MariaDB** (port 3306)
   - Base: `radius`
   - User: `radiususer` + `sae501_php`
   - Créé par: `install_mysql.sh`

2. **FreeRADIUS** (port 1812 UDP)
   - Base de données: MySQL radius
   - User test: `wifi_user` / `password123`
   - Secret: `testing123`
   - Créé par: `install_radius.sh`

3. **Apache2 + PHP** (port 80)
   - Interface: `/var/www/html/php-admin/`
   - Base de données: MySQL radius
   - Créé par: `install_php_admin.sh`

### 🚀 Prêt à utiliser:

```bash
# Sur Debian 11 VM:
sudo bash scripts/install_all.sh
```

Ce script:
1. Met à jour le système
2. Installe MySQL/MariaDB
3. Installe FreeRADIUS avec BD configurée
4. Installe Apache2 + PHP
5. Vérifie tous les services
6. Crée un utilisateur test
7. Stocke les identifiants en sécurité

### ✅ Valides pour:
- Debian 11
- VirtualBox NAT interface
- Installation locale (sans routeur TP-Link au départ)
- Accès futurs routeur possibles

### 📝 Fichiers de script conservés:
- `scripts/install_all.sh` - Script principal
- `scripts/install_mysql.sh` - Installation BD
- `scripts/install_radius.sh` - FreeRADIUS
- `scripts/install_php_admin.sh` - Interface web
- `scripts/diagnostics.sh` - Vérifications
- `scripts/test_installation.sh` - Tests
- `scripts/test_security.sh` - Tests sécurité

### ⚠️ Notes importantes:
- Les identifiants sont stockés en sécurité dans `/opt/sae501/secrets/db.env`
- Les scripts sont idempotents (peuvent être exécutés plusieurs fois)
- La configuration est optimisée pour localhost (NAT VM)
- Prêt pour configuration routeur TP-Link plus tard

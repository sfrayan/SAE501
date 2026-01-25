# Scripts SAE501

## 🚀 Lancement rapide

Pour **installer complètement** SAE501 sur Debian 11:

```bash
# Option 1: Via QUICK_RUN (recommandé)
sudo bash scripts/QUICK_RUN.sh

# Option 2: Direct
sudo bash scripts/install_all.sh
```

## 📄 Scripts disponibles

### Installation
| Script | Fonction | Lancé par |
|--------|----------|-------|
| `install_all.sh` | **PRINCIPAL** - Installation complète | QUICK_RUN |
| `install_mysql.sh` | MySQL/MariaDB + Base radius | install_all.sh |
| `install_radius.sh` | FreeRADIUS configuré | install_all.sh |
| `install_php_admin.sh` | Apache2 + PHP + Interface web | install_all.sh |
| `QUICK_RUN.sh` | Wrapper simplifié | Vous! |

### Utilitaires
| Script | Fonction |
|--------|----------|
| `diagnostics.sh` | Vérifier tous les services |
| `test_installation.sh` | Test complet du système |
| `test_security.sh` | Test de sécurité |
| `show_credentials.sh` | Afficher identifiants stockés |
| `generate_certificates.sh` | Générer certificats SSL |
| `clean_reinstall.sh` | Réinitialiser l'installation |

## ✅ Après installation

```bash
# Vérifier l'état
sudo bash scripts/diagnostics.sh

# Lancer les tests
bash scripts/test_installation.sh

# Voir les identifiants
bash scripts/show_credentials.sh
```

## 🔍 Services qui tournent

Après lancement:

1. **MySQL/MariaDB** sur port 3306
   - Base: `radius`
   - Users: `radiususer`, `sae501_php`

2. **FreeRADIUS** sur port 1812 (UDP)
   - Utilisateur test: `wifi_user` / `password123`
   - Secret: `testing123`

3. **Apache2** sur port 80
   - URL: `http://localhost/`

## 🗐 Stockage sécurisé

Identifiants stockés dans:
```
/opt/sae501/secrets/db.env
```

Permissions: `640` (root:www-data)

## 🔧 Aide

```bash
# Vérifier FreeRADIUS est actif
sudo systemctl status freeradius

# Voir les logs
sudo journalctl -u freeradius -f

# Relancer FreeRADIUS
sudo systemctl restart freeradius

# Vérifier Apache
sudo systemctl status apache2

# Vérifier MySQL
sudo systemctl status mysql
```

## 😲 Problèmes?

1. **FreeRADIUS pas actif** → `sudo systemctl restart freeradius`
2. **Apache ne démarre pas** → Vérifier port 80 libre
3. **MySQL refuse connexion** → `sudo systemctl restart mysql`
4. **Identifiants oubliés** → `cat /opt/sae501/secrets/db.env`

## 🔎 Configuration TP-Link (futur)

Une fois le routeur connecté:

```
Serveur RADIUS:  IP_VM (ex: 192.168.1.100)
Port:           1812
Secret:         testing123
```

---

**Besoin d'aide?** Consultez `/docs/` ou les logs dans `/tmp/sae501_install_*.log`

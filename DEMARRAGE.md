# 🚀 DÉMARRAGE RAPIDE - 2 MINUTES

## 📄 Ce qui vient d'être fait

1. ✅ **install_all.sh** - CORRIGÉ (cohérence des services)
2. 📝 **Documentation** - Créée (ARCHITECTURE.md, CLEANUP_LOG.md, STATUS.md)
3. 🗐 **QUICK_RUN.sh** - Lancement facile créé
4. ✅ **Services** - Tous configurés correctement

## 🚀 MAINTENANT: LANCER L'INSTALLATION

### Sur votre VM Debian 11:

```bash
# 1. Télécharger le repo
cd /tmp
git clone https://github.com/sfrayan/SAE501.git
cd SAE501

# 2. Lancer l'installation (une seule commande!)
sudo bash scripts/QUICK_RUN.sh
```

**C'est tout!** L'installation:
- Installe MySQL + BD radius
- Installe FreeRADIUS
- Installe Apache2 + PHP
- Crée utilisateur test (wifi_user/password123)
- Vérifie que tout fonctionne
- Stocke les identifiants sécurisément

## 👋 Après l'installation

### Vérifier que tout marche:

```bash
# Vérifier MySQL
sudo systemctl status mysql

# Vérifier FreeRADIUS
sudo systemctl status freeradius

# Vérifier Apache
sudo systemctl status apache2

# Tester RADIUS
radtest wifi_user password123 localhost 1812 testing123
```

### Voir les identifiants:

```bash
cat /opt/sae501/secrets/db.env
```

## 🌏 Accés aux services

**Sur la VM Debian 11**:
- MySQL: `localhost:3306`
- FreeRADIUS: `localhost:1812` (UDP)
- Apache: `http://localhost/`

## 📊 Fichiers importants

```
scripts/
  └─ QUICK_RUN.sh         <- Lancer ceci!
  └─ install_all.sh      <- Ou ceci
  └─ README.md           <- Aide détaillée

ROOT:
  └─ ARCHITECTURE.md     <- Schéma complet
  └┠ STATUS.md          <- État actuel
  └─ CLEANUP_LOG.md      <- Ce qui a changé
```

## ✅ Checklist d'installation

- [ ] `sudo bash scripts/QUICK_RUN.sh` lancé
- [ ] Attendre que l'installation finisse (5-10 min)
- [ ] Vérifier `sudo systemctl status freeradius`
- [ ] Vérifier `radtest wifi_user password123 localhost 1812 testing123`
- [ ] Vérifier `cat /opt/sae501/secrets/db.env`

## 🔍 Si problème

```bash
# Voir les logs d'installation
cat /tmp/sae501_install_*.log

# Relancer les diagnostics
sudo bash scripts/diagnostics.sh

# Relancer juste FreeRADIUS
sudo systemctl restart freeradius

# Voir les logs FreeRADIUS
sudo journalctl -u freeradius -f
```

## 🔨 Configuration TP-Link (futur)

Quand vous recevrez le routeur:

1. Connecter le routeur en réseau
2. Dans le routeur, configurer RADIUS:
   - Serveur: IP_VM (ex: 192.168.1.100)
   - Port: 1812
   - Secret: testing123
3. Tester authentification Wi-Fi!

## 📄 Documents de référence

- **scripts/README.md** - Guide complet des scripts
- **ARCHITECTURE.md** - Schéma et flux de données
- **STATUS.md** - État complet du project
- **CLEANUP_LOG.md** - Modifications apportées

---

## 🎆 PROCHAINES COMMANDES

```bash
# 1. LANCER L'INSTALLATION
sudo bash scripts/QUICK_RUN.sh

# 2. VÉRIFIER
bash scripts/test_installation.sh

# 3. TERMINER
echo "Installation terminée! RADIUS prêt pour routeur TP-Link."
```

---

**C'est aussi simple que ça!** 🈟

Tous les fichiers de configuration et d'incohérence ont été corrigés.
Vous pouvez lancer `sudo bash scripts/QUICK_RUN.sh` maintenant.

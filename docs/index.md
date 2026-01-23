---
layout: default
title: SAE501 - Architecture Wi-Fi Sécurisée
---

# 💫 SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

## Bienvenue!

SAE501 est une **infrastructure d'authentification RADIUS sécurisée** pour WPA-Enterprise.

### 🌟 Objectifs

- 💫 Authentification centralisée (PEAP-MSCHAPv2)
- 👎 Gestion d'utilisateurs facile
- 📊 Monitoring en temps réel
- 🔐 Logs d'audit complets
- ⚡ Installation 5-10 minutes

---

## 🚀 Démarrage rapide

### Installation automatisée (recommandé)

```bash
git clone https://github.com/sfrayan/SAE501.git
cd SAE501
sudo bash scripts/install_all.sh
```

**Durée**: 15-20 minutes

### Vérification

```bash
bash scripts/test_installation.sh
bash scripts/show_credentials.sh
```

---

## 💻 Composants

| Composant | Port | Rôle |
|-----------|------|------|
| **FreeRADIUS** | 1812/1813 | Authentification |
| **PHP-Admin** | 80/443 | Interface de gestion |
| **MySQL** | 3306 | Base de données |
| **Wazuh** | 5601/55000 | Monitoring |

---

## 📁 Documentation complète

Pour le guide complet **étape par étape**:

👉 **[Lire le README.md](https://github.com/sfrayan/SAE501#readme)**

Le README inclut:
- Pré-requis système
- 9 étapes d'installation
- Configuration du routeur
- Gestion des utilisateurs
- Sécurité et maintenance
- Dépannage

---

## 📚 Fichiers de documentation

### Architecture
- [Dossier d'architecture](dossier-architecture.md) - Vue technique complète
- [Hardening Linux](hardening-linux.md) - Sécurité rénforcée
- [Journal de bord](journal-de-bord.md) - Avancements du projet

---

## 🛠️ Accès rapides

### Interfaces web

```
PHP-Admin:     http://VOTRE_IP/admin
Wazuh:         https://VOTRE_IP:5601
```

### Identifiants par défaut

```bash
# Afficher tous les accès créés
bash scripts/show_credentials.sh
```

### Commandes essentielles

```bash
# Installation
sudo bash scripts/install_all.sh

# Tests
bash scripts/test_installation.sh

# Vérification
bash scripts/show_credentials.sh

# Diagnostics
bash scripts/diagnostics.sh
```

---

## ✅ Status

- ✅ Installation: **5-10 minutes**
- ✅ Pages PHP: **7/7 complètes**
- ✅ Scripts: **8 automatisés**
- ✅ Tests: **10 catégories**
- ✅ Production-ready: **95%**

---

## 🚇 Support

### Problèmes?

```bash
# Diagnostics complets
bash scripts/diagnostics.sh

# Vérifier l'état
bash scripts/test_installation.sh

# Voir les logs
sudo tail -f /var/log/freeradius/radius.log
```

### Documentation technique

Voir [dossier-architecture.md](dossier-architecture.md) pour:
- Schémas d'architecture
- Flux d'authentification
- Scénarios de dépannage

---

## 📋 Guide complet

### ÉTAPE 1: Préparation
- Créer une VM (4GB RAM, 2 CPU, 50GB disque)
- Installer Debian 12+ ou Ubuntu 22.04+
- Vérifier connexion internet

### ÉTAPE 2: Installation
```bash
sudo bash scripts/install_all.sh
```

### ÉTAPE 3: Vérification
```bash
bash scripts/test_installation.sh
bash scripts/show_credentials.sh
```

### ÉTAPE 4: Configuration
- Accéder PHP-Admin
- Changer les mots de passe
- Ajouter utilisateurs
- Configurer routeur

### ÉTAPE 5: Maintenance
- Consulter logs d'audit
- Monitorer Wazuh
- Sauvegarder la base de données

---

## 🔐 Sécurité

### AVANT PRODUCTION

- [ ] Changez TOUS les mots de passe
- [ ] Générez certificats SSL/TLS
- [ ] Activez HTTPS partout
- [ ] Configurez firewall UFW
- [ ] Testez sauvegardes

### Bonnes pratiques

```bash
# Firewall
sudo ufw enable
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 1812/udp    # RADIUS
sudo ufw allow 5601/tcp    # Wazuh

# Sauvegardes
mysqldump -u root -p radius > backup.sql
```

---

## 📊 Statistiques

| Métrique | Valeur |
|----------|--------|
| Fichiers PHP | 7 |
| Scripts | 8 |
| Tests automatisés | 10+ |
| Temps installation | 5-10 min |
| Production-readiness | 95% |

---

## 🔗 Liens

- 📖 **[README complet](https://github.com/sfrayan/SAE501#readme)**
- 💻 **[GitHub Repository](https://github.com/sfrayan/SAE501)**
- 📊 **[Architecture document](dossier-architecture.md)**
- 🔐 **[Security guide](hardening-linux.md)**

---

## 🌟 Prêt?

```bash
git clone https://github.com/sfrayan/SAE501.git
cd SAE501
sudo bash scripts/install_all.sh
```

**Bienvenue dans SAE501! 🚀**

---

*Architecture Wi-Fi Sécurisée - Projet SAE*
*Dernière mise à jour: 23 janvier 2026*

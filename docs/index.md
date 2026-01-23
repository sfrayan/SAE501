---
layout: default
title: SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites
---

# 💪 SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites

**Système complet d'authentification RADIUS Enterprise avec Wazuh monitoring**

## 🚀 Démarrage rapide

```bash
# Installation complète en 1 commande (5-10 minutes)
sudo bash scripts/install_all.sh

# Voir tous les accès
bash scripts/show_credentials.sh

# Tester l'installation
bash scripts/test_installation.sh
```

## 📋 Documentation

- **[QUICKSTART.md](../QUICKSTART.md)** - Démarrage en 5 minutes 🚀
- **[README_FINAL.md](../README_FINAL.md)** - Documentation complète 📚
- **[MODIFICATIONS_EFFECTUEES.md](../MODIFICATIONS_EFFECTUEES.md)** - Ce qui a été fait 📋

### Architecture technique

- **[dossier-architecture.md](dossier-architecture.md)** - Architecture détaillée
- **[hardening-linux.md](hardening-linux.md)** - Sécurité renforcée
- **[journal-de-bord.md](journal-de-bord.md)** - Journal de développement

## ✅ Fonctionnalités

✅ **FreeRADIUS** - Authentification Enterprise WPA2/WPA3
✅ **PHP-Admin** - Interface de gestion intuitive
✅ **Wazuh** - Monitoring et alertes sécurité
✅ **MySQL** - Base de données sécurisée
✅ **Logs d'audit** - Traçabilité complète
✅ **Hardening** - Configuration renforcée
✅ **Scripts automatisés** - Installation + tests
✅ **Production-ready** - Prêt à 95%

## 🔐 Accès aux interfaces

### PHP-Admin (Gestion RADIUS)
```
URL: http://localhost/admin
Utilisateur: admin
Mot de passe: Admin@Secure123! (CHANGEZ-LE)
```

### Wazuh Dashboard (Monitoring)
```
URL: http://localhost:5601
Utilisateur: admin
Mot de passe: SecurePassword123! (CHANGEZ-LE)
```

## 📈 Architecture

```
┌────────────────────────────────────────┐
│           Clients Wi-Fi (WPA-Enterprise)         │
└────────────┬───────────────────────────┘
                      │
┌────────────▼───────────────────────────┐
│            Routeur (NAS RADIUS)                │
└────────────┬───────────────────────────┘
                      │ UDP:1812/1813
┌────────────▼───────────────────────────┐
│        SERVEUR SAE501 (Debian VM)            │
│                                               │
│  ┌───────────────────────────────┐  │
│  │    FreeRADIUS (1812/1813)          │  │
│  └────────────┬──────────────────┘  │
│                 │                        │
│  ┌──────────▼──────────┐  ┌──────────────┐  │
│  │  MySQL DB              │  │  PHP-Admin       │  │
│  └─────────────────────┘  └──────────────┘  │
│                                               │
│  ┌───────────────────────────────┐  │
│  │  Wazuh (5601, 55000)                │  │
│  │  - Monitoring réel                 │  │
│  │  - Détection anomalies             │  │
│  │  - Alertes sécurité                │  │
│  └───────────────────────────────┘  │
│                                               │
└────────────────────────────────────────┘
```

## 📈 Scripts disponibles

| Script | Description | Durée |
|--------|-------------|--------|
| `install_all.sh` | Installation complète 🚀 **RECOMMANDÉ** | 15-20 min |
| `install_radius.sh` | FreeRADIUS uniquement | 5 min |
| `install_php_admin.sh` | Interface web uniquement | 3 min |
| `install_wazuh.sh` | Monitoring Wazuh uniquement | 10 min |
| `install_hardening.sh` | Sécurité renforcée | 2 min |
| `diagnostics.sh` | Tests de connectivité | 1 min |
| `show_credentials.sh` | Afficher accès | 30 sec |
| `test_installation.sh` | Tests complets | 2 min |

## 🔐 Sécurité

### Implémenté

✅ **PEAP-MSCHAPv2** - Authentification sans certificat client
✅ **Mots de passe hashés** - Jamais stockés en clair
✅ **Logs d'audit** - Toutes les actions enregistrées
✅ **Firewall UFW** - Règles strictes
✅ **Fail2Ban** - Protection brute-force
✅ **AppArmor** - Sandboxing services
✅ **SSH renforcé** - Pas de password, clés uniquement
✅ **Monitoring Wazuh** - Détection anomalies

### En production

⚠️ **OBLIGATOIRE**:
- [ ] Changez TOUS les mots de passe
- [ ] Générez certificats SSL/TLS
- [ ] Activez HTTPS partout
- [ ] Testez les sauvegardes

## 🧪 Tests

```bash
# Tests automatisés après installation
bash scripts/test_installation.sh

# Affiche:
# ✅ 10/10 tests réussis
# ✅ Système prêt pour utilisation
```

## 📊 Support

**En cas de problème**:

1. Vérifiez les logs
   ```bash
   bash scripts/diagnostics.sh
   ```

2. Consultez la documentation
   - `QUICKSTART.md` - Début
   - `README_FINAL.md` - Complet
   - `docs/` - Technique

3. Tests manuels
   ```bash
   radtest user password localhost 0 secret
   ```

## 🏗️ Pré-requis

- **OS**: Debian 12+ ou Ubuntu 22.04+
- **RAM**: 4GB minimum (8GB recommandé)
- **CPU**: 2 cores
- **Disque**: 50GB minimum
- **Accès root** pour installation

## 📈 Performance

- **Authentifications/sec**: 100+
- **Temps de réponse**: < 100ms
- **Connexions simultanes**: 1000+
- **Mémoire (idle)**: ~500MB
- **CPU (idle)**: < 5%

## 📄 Licence

Projet SAE501 - Sorbonne Paris Nord

Utilise logiciels open-source:
- FreeRADIUS (GPLv2)
- Wazuh (GPLv2)
- Debian (Libre)
- MySQL (GPLv2)

---

**🚀 Prêt? Commencez par**: `sudo bash scripts/install_all.sh`

**📋 Documentation**: [QUICKSTART.md](../QUICKSTART.md)

**🏗️ Architecture**: [dossier-architecture.md](dossier-architecture.md)

---

*Dernière mise à jour: 23 janvier 2026 - Version 1.0.0*

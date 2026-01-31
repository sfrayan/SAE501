# SAE501 - Documentation des Tests

## 🧪 Vue d'ensemble

Le dossier `tests/` contient une suite complète de tests automatisés pour valider l'installation et la sécurité du projet SAE501.

---

## 📁 Fichiers de tests disponibles

### **run_all_tests.sh** ⭐ **(RECOMMANDÉ)**

**Script principal de validation complète**

```bash
sudo bash tests/run_all_tests.sh
```

**Teste automatiquement**:
- ✅ **Services**: MySQL, FreeRADIUS, Apache, PHP-FPM, Wazuh
- ✅ **Réseau**: Ports 22, 80, 443, 1812, 1813, 3306, 5601
- ✅ **Base de données**: Tables, utilisateurs, accès
- ✅ **RADIUS**: Configuration, modules SQL/EAP, authentification
- ✅ **PHP-Admin**: Pages, permissions, configuration
- ✅ **UFW Firewall**: Actif, règles, politique
- ✅ **SSH**: Root disabled, MaxAuthTries, X11 Forwarding, chiffrements
- ✅ **Fail2Ban**: Jails SSH/Apache, IPs bannies
- ✅ **Auditd**: Règles, surveillance fichiers critiques
- ✅ **Kernel**: ASLR, TCP SYN cookies, RP filtering
- ✅ **Permissions**: /etc/shadow, /etc/passwd, SSH config, RADIUS config
- ⚠️ **Sécurité**: Détection mots de passe par défaut

**Résultat**:
```
================================================================
                    RÉSUMÉ DES TESTS
================================================================

Total des tests      : 65
Tests réussis       : 60
Tests échoués       : 0
Avertissements      : 5

Taux de réussite    : 92% 🎉

================================================================
  ✓ TOUS LES TESTS CRITIQUES RÉUSSIS!
  🎆 Installation SAE501 opérationnelle
================================================================
```

---

### **test_peap.sh**

**Tests spécifiques PEAP-MSCHAPv2**

```bash
sudo bash tests/test_peap.sh
```

**Vérifie**:
- Configuration EAP-PEAP
- Module mschap
- Certificats SSL
- Tests d'authentification PEAP

---

### **test_isolement.sh**

**Tests de sécurité réseau**

```bash
sudo bash tests/test_isolement.sh
```

**Vérifie**:
- Isolation des VLANs
- Firewall entre réseaux
- Routing et ACL
- Tests de connectivité inter-VLAN

---

### **test_syslog_mr100.sh**

**Tests monitoring Meraki MR100**

```bash
sudo bash tests/test_syslog_mr100.sh
```

**Vérifie**:
- Réception logs syslog
- Configuration rsyslog
- Monitoring équipements Meraki
- Alertes personnalisées

---

## 🚀 Utilisation recommandée

### Après installation complète

```bash
# 1. Installation
sudo bash scripts/install_mysql.sh
sudo bash scripts/install_radius.sh
sudo bash scripts/install_php_admin.sh
sudo bash scripts/install_hardening.sh

# 2. Validation automatique
sudo bash tests/run_all_tests.sh

# 3. Si tous les tests passent → Production ready!
```

### Après modification de configuration

```bash
# Après changement de config SSH
sudo bash tests/run_all_tests.sh | grep -A 10 "SSH"

# Après modification RADIUS
radtest testuser testpass localhost 0 testing123
sudo bash tests/run_all_tests.sh | grep -A 10 "RADIUS"

# Après configuration firewall
sudo bash tests/run_all_tests.sh | grep -A 10 "UFW"
```

### Surveillance régulière

```bash
# Chaque semaine - Test de santé du système
sudo bash tests/run_all_tests.sh > /var/log/sae501_health_$(date +%Y%m%d).log

# Analyser les résultats
grep -E "FAIL|WARN" /var/log/sae501_health_*.log
```

---

## 📊 Interprétation des résultats

### Codes de sortie

| Code | Signification | Action |
|------|---------------|--------|
| `0` | Tous tests critiques OK | Production ready |
| `1` | Échecs détectés | Vérifier logs et corriger |

### Indicateurs visuels

| Symbole | Signification | Priorité |
|---------|---------------|----------|
| ✅ `✓` | Test réussi | Normal |
| ❌ `✗` | Test échoué | **CRITIQUE** |
| ⚠️ `⚠` | Avertissement | Attention |
| ℹ️ `ℹ` | Information | OK |

### Taux de réussite

- **≥ 90%**: 🎉 Excellent - Système opérationnel
- **70-89%**: 👍 Bon - Quelques ajustements recommandés
- **< 70%**: ⚠️ Problèmes - Revoir l'installation

---

## 🔧 Dépannage

### Tests échoués courants

#### MySQL/MariaDB inactif
```bash
sudo systemctl status mysql
sudo systemctl start mysql
sudo bash tests/run_all_tests.sh
```

#### FreeRADIUS ne répond pas
```bash
sudo systemctl status freeradius
sudo freeradius -X  # Mode debug
sudo tail -f /var/log/freeradius/radius.log
```

#### UFW firewall inactif
```bash
sudo ufw enable
sudo ufw status verbose
```

#### Fail2Ban non détecté
```bash
sudo systemctl status fail2ban
sudo systemctl start fail2ban
sudo fail2ban-client status
```

#### Auditd inactif
```bash
sudo systemctl status auditd
sudo systemctl start auditd
sudo auditctl -l
```

### Avertissements fréquents

#### "Secret RADIUS par défaut détecté"

⚠️ **CRITIQUE** - Changez immédiatement!

```bash
sudo nano /etc/freeradius/3.0/clients.conf
# Remplacez: secret = testing123
# Par: secret = VotreSecret@Sécurisé!
sudo systemctl restart freeradius
```

#### "PHP-FPM non détecté"

Relancer l'installation:
```bash
sudo bash scripts/install_php_admin.sh
```

#### "Jail Apache non détectée"

Vérifier configuration Fail2Ban:
```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

---

## 📝 Logs et rapports

### Générer un rapport complet

```bash
# Rapport texte
sudo bash tests/run_all_tests.sh > rapport_$(date +%Y%m%d_%H%M%S).txt

# Rapport avec timestamp
sudo bash tests/run_all_tests.sh 2>&1 | tee /tmp/sae501_test_report.log
```

### Automatiser les tests

**Cron quotidien**:
```bash
sudo crontab -e

# Ajouter:
0 3 * * * /bin/bash /root/SAE501/tests/run_all_tests.sh > /var/log/sae501_daily_$(date +\%Y\%m\%d).log 2>&1
```

**Alerte sur échec**:
```bash
#!/bin/bash
# /root/test_and_alert.sh

if ! sudo bash /root/SAE501/tests/run_all_tests.sh; then
    echo "Tests SAE501 échoués le $(date)" | mail -s "[ALERTE] SAE501" admin@example.com
fi
```

---

## ✅ Checklist avant production

### Tests obligatoires

- [ ] `run_all_tests.sh` exécuté avec succès (0 échec)
- [ ] Taux de réussite ≥ 90%
- [ ] Tous les services actifs (MySQL, RADIUS, Apache)
- [ ] Ports réseau écoutés (1812, 1813, 80, 22, 3306)
- [ ] UFW firewall actif et configuré
- [ ] Fail2Ban actif (jails SSH + Apache)
- [ ] Auditd surveille fichiers critiques
- [ ] Test d'authentification RADIUS réussi
- [ ] PHP-Admin accessible
- [ ] Aucun mot de passe par défaut détecté

### Actions post-tests

- [ ] Changement mots de passe (PHP-Admin, MySQL, Wazuh)
- [ ] Changement secret RADIUS
- [ ] Activation HTTPS
- [ ] Configuration routeur Wi-Fi
- [ ] Test connexion Wi-Fi réelle
- [ ] Documentation procédures
- [ ] Formation équipe

---

## 🔍 Tests spécialisés

### Test de charge RADIUS

```bash
# Installer radperf
sudo apt install freeradius-utils

# Test 100 requêtes/sec pendant 10s
for i in {1..1000}; do
    radtest user$i password localhost 0 testing123 &
done
wait

# Analyser logs
sudo grep "Access-Accept" /var/log/freeradius/radius.log | wc -l
```

### Test de pénétration SSH

```bash
# Simuler bruteforce (attention!)
for i in {1..10}; do
    ssh invalid_user@localhost
done

# Vérifier Fail2Ban
sudo fail2ban-client status sshd
```

### Test d'audit fichiers

```bash
# Modifier fichier surveillé
sudo nano /etc/ssh/sshd_config

# Vérifier logs auditd
sudo ausearch -k sshd_config_changes -ts today
```

---

## 📚 Ressources additionnelles

- **Documentation principale**: `../README.md`
- **Scripts installation**: `../scripts/`
- **Configuration RADIUS**: `../radius/`
- **Docs techniques**: `../docs/`

---

## 💬 Support

En cas de problème avec les tests:

1. Consultez les logs: `journalctl -xe`
2. Vérifiez diagnostics: `bash scripts/diagnostics.sh`
3. Exécutez tests en mode verbose
4. Ouvrez une issue: [GitHub Issues](https://github.com/sfrayan/SAE501/issues)

---

*SAE501 - Tests Automatisés*  
*Dernière mise à jour: 31 janvier 2026*  
*Version: 1.0*

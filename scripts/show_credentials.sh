#!/bin/bash

################################################################################
# SAE501 - Afficher les accès et identifiants
# Utilitaire pour afficher rapidement tous les accès au système
################################################################################

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                   SAE501 - Accès et identifiants                          ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Vérifier si les services sont actifs
echo "📊 STATUT DES SERVICES"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""

echo -n "FreeRADIUS:        "
if systemctl is-active --quiet radiusd; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo -n "MySQL:             "
if systemctl is-active --quiet mysql; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo -n "PHP-FPM:           "
if systemctl is-active --quiet php-fpm; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo -n "Apache2:           "
if systemctl is-active --quiet apache2; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo -n "Wazuh Manager:     "
if systemctl is-active --quiet wazuh-manager; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo -n "Elasticsearch:     "
if systemctl is-active --quiet elasticsearch; then
    echo "✓ ACTIF"
else
    echo "✗ INACTIF"
fi

echo ""
echo "🔐 IDENTIFIANTS"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""

echo "┌─ PHP-Admin (Gestion RADIUS)"
echo "│  URL:          http://localhost/admin"
echo "│  Utilisateur:  admin"
echo "│  Mot de passe: Admin@Secure123!"
echo "│  ⚠ CHANGEZ le mot de passe en production"
echo "└"
echo ""

echo "┌─ Wazuh Dashboard (Monitoring)"
echo "│  URL:          http://localhost:5601"
echo "│  Utilisateur:  admin"
echo "│  Mot de passe: SecurePassword123!"
echo "│  ⚠ CHANGEZ le mot de passe en production"
echo "└"
echo ""

echo "┌─ Base de données MySQL"
echo "│  Hôte:         localhost"
echo "│  Port:         3306"
echo "│  Utilisateur:  radiusapp"
echo "│  Mot de passe: RadiusApp@Secure123!"
echo "│  Base:         radius"
echo "│  ⚠ CHANGEZ le mot de passe en production"
echo "└"
echo ""

echo "┌─ FreeRADIUS"
echo "│  Serveur:      localhost"
echo "│  Port Auth:    1812"
echo "│  Port Account: 1813"
echo "│  Secret:       ConsultezPHP-Admin (Paramétrages)"
echo "└"
echo ""

echo "🌐 SERVICES ET PORTS"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""
echo "  Service              | Port | URL"
echo "  ─────────────────────┼──────┼──────────────────────────────────"
echo "  PHP-Admin            | 80   | http://localhost/admin"
echo "  Wazuh Dashboard      | 5601 | http://localhost:5601"
echo "  Wazuh API            | 55000| https://localhost:55000"
echo "  FreeRADIUS (Auth)    | 1812 | udp://localhost:1812"
echo "  FreeRADIUS (Account) | 1813 | udp://localhost:1813"
echo "  MySQL                | 3306 | localhost:3306"
echo "  Elasticsearch        | 9200 | http://localhost:9200"
echo ""

echo "📝 LOGS ET DIAGNOSTICS"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""
echo "Voir les logs:"
echo "  RADIUS:     sudo tail -f /var/log/freeradius/radius.log"
echo "  Apache:     sudo tail -f /var/log/apache2/error.log"
echo "  PHP-FPM:    sudo tail -f /var/log/php-fpm.log"
echo "  Wazuh:      sudo tail -f /var/ossec/logs/ossec.log"
echo ""
echo "Diagnostics complets:"
echo "  bash scripts/diagnostics.sh"
echo ""

echo "🛡️  RECOMMANDATIONS DE SÉCURITÉ"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""
echo "  ⚠ AVANT PRODUCTION:"
echo "    1. Changez TOUS les mots de passe par défaut"
echo "    2. Activez SSL/TLS pour HTTPS"
echo "    3. Configurez le pare-feu et les règles iptables"
echo "    4. Limitez l'accès aux services"
echo "    5. Mettez à jour tous les paquets système"
echo "    6. Activez 2FA si disponible"
echo "    7. Sauvegardez régulièrement la base de données"
echo "    8. Configurez le monitoring et les alertes"
echo ""

echo "ℹ️  DOCUMENTATION"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""
echo "  Démarrage rapide:      QUICKSTART.md"
echo "  Architecture:          docs/dossier-architecture.md"
echo "  Hardening:             docs/hardening-linux.md"
echo "  Journal de bord:       docs/journal-de-bord.md"
echo "  Documentation complète: README.md"
echo ""

echo "═════════════════════════════════════════════════════════════════════════════"
echo "Système SAE501 - Architecture Wi-Fi Sécurisée Multi-Sites"
echo "═════════════════════════════════════════════════════════════════════════════"
echo ""

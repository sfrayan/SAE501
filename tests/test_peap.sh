#!/bin/bash
# ============================================================================
# SAE501 - Test PEAP-MSCHAPv2 Authentication
# Vérifie que l'authentification fonctionne correctement
# ============================================================================

set -euo pipefail

echo "=== SAE501 PEAP-MSCHAPv2 Test ==="
echo ""

# Check if RADIUS is running
echo "[1] Vérification que FreeRADIUS est en cours d'exécution..."
if ! systemctl is-active freeradius > /dev/null 2>&1; then
    echo "ERROR: FreeRADIUS n'est pas actif"
    echo "Démarrer: sudo systemctl start freeradius"
    exit 1
fi
echo "OK - FreeRADIUS actif"
echo ""

# Check if RADIUS is listening
echo "[2] Vérification que RADIUS écoute sur le port 1812..."
if ! netstat -ulpn 2>/dev/null | grep -q ":1812"; then
    echo "WARNING: RADIUS ne semble pas écouter sur 1812"
    echo "Vérifier la configuration: sudo radiusd -C"
else
    echo "OK - RADIUS écoute sur 1812"
fi
echo ""

# Check database connection
echo "[3] Vérification de la connexion MariaDB..."
if ! mysql -u radiususer -p"${DB_PASSWORD_RADIUS:-password}" radius -e "SELECT COUNT(*) FROM radcheck;" > /dev/null 2>&1; then
    echo "WARNING: Impossible de se connecter à la base de données"
    echo "Vérifier les identifiants dans /opt/sae501/secrets/db.env"
else
    count=$(mysql -u radiususer -p"${DB_PASSWORD_RADIUS:-password}" radius -e "SELECT COUNT(*) FROM radcheck;" 2>/dev/null | tail -1)
    echo "OK - MariaDB connecté ($count comptes)"
fi
echo ""

# Test authentication request
echo "[4] Test d'authentification avec testuser..."
echo "User-Name = 'testuser', User-Password = 'password123'" | \
  radclient -f - localhost:1812 auth testing123 > /tmp/radius_test.log 2>&1

if grep -q "Access-Accept" /tmp/radius_test.log; then
    echo "OK - Authentification ACCEPTÉE"
    cat /tmp/radius_test.log
elif grep -q "Access-Reject" /tmp/radius_test.log; then
    echo "WARNING - Authentification REJÉTÉE"
    cat /tmp/radius_test.log
    echo ""
    echo "Possibilités:"
    echo "1. Utilisateur testuser n'existe pas ou mot de passe incorrect"
    echo "2. Ajouter un utilisateur avec: sudo mysql -u radiususer -p radius"
    echo "   INSERT INTO radcheck (username, attribute, op, value) VALUES ('testuser', 'User-Password', ':=', 'password123');"
else
    echo "ERROR - Pas de réponse RADIUS"
    cat /tmp/radius_test.log
fi
echo ""

# Check RADIUS logs
echo "[5] Vérification des logs RADIUS..."
if [ -f /var/log/sae501/radius/auth.log ]; then
    echo "Dernières entrées auth.log:"
    tail -5 /var/log/sae501/radius/auth.log
else
    echo "WARNING: Fichier log auth.log non trouvé"
fi
echo ""

# Check certificate
echo "[6] Vérification du certificat PEAP..."
if [ -f /etc/radius/certs/server.crt ]; then
    expiration=$(openssl x509 -in /etc/radius/certs/server.crt -noout -enddate | cut -d= -f2)
    echo "Certificat trouvé"
    echo "Expiration: $expiration"
else
    echo "WARNING: Certificat PEAP non trouvé"
fi
echo ""

echo "=== Test terminé ==="
echo ""
echo "Pour ajouter un utilisateur de test:"
echo "  sudo mysql -u radiususer -pRADIUS_PASSWORD radius"
echo "  INSERT INTO radcheck (username, attribute, op, value) VALUES ('testuser', 'User-Password', ':=', 'password123');"
echo ""
echo "Pour tester depuis un client Wi-Fi:"
echo "  SSID: Entreprise"
echo "  Méthode: PEAP"
echo "  Authentification interne: MSCHAPv2"
echo "  Username: testuser"
echo "  Password: password123"
echo ""

-- ============================================================================
-- SAE501 - Initialisation des utilisateurs RADIUS de test
-- Crée des comptes pour les tests d'authentification
-- ============================================================================

-- IMPORTANT: Les mots de passe sont ici pour démonstration uniquement!
-- En production, utiliser des mot de passe forts et un hash MD4/NT

USE radius;

-- ============================================================================
-- UTILISATEURS DE TEST
-- ============================================================================

-- Utilisateur de test standard
INSERT IGNORE INTO radcheck (
    username, 
    attribute, 
    op, 
    value
) VALUES (
    'testuser',
    'User-Password',
    ':=',
    'password123'
);

-- Utilisateur employé
INSERT IGNORE INTO radcheck (
    username,
    attribute,
    op,
    value
) VALUES (
    'employe1',
    'User-Password',
    ':=',
    'EmployeePass@2024'
);

-- Utilisateur employé
INSERT IGNORE INTO radcheck (
    username,
    attribute,
    op,
    value
) VALUES (
    'employe2',
    'User-Password',
    ':=',
    'EmployeePass@2024'
);

-- Admin local pour tests
INSERT IGNORE INTO radcheck (
    username,
    attribute,
    op,
    value
) VALUES (
    'admin',
    'User-Password',
    ':=',
    'AdminSecure@2024'
);

-- ============================================================================
-- ATTRIBUTS DE REPONSE (Reply Attributes)
-- ============================================================================

-- Attribuer des droits à testuser
INSERT IGNORE INTO radreply (
    username,
    attribute,
    op,
    value
) VALUES (
    'testuser',
    'Reply-Message',
    ':=',
    'Access granted'
);

-- Attribuer des droits aux employés
INSERT IGNORE INTO radreply (
    username,
    attribute,
    op,
    value
) VALUES (
    'employe1',
    'Service-Type',
    ':=',
    'Framed-User'
);

INSERT IGNORE INTO radreply (
    username,
    attribute,
    op,
    value
) VALUES (
    'employe2',
    'Service-Type',
    ':=',
    'Framed-User'
);

-- ============================================================================
-- SUIVI D'ETAT
-- ============================================================================

INSERT IGNORE INTO user_status (
    username,
    active,
    created_at
) VALUES 
    ('testuser', TRUE, NOW()),
    ('employe1', TRUE, NOW()),
    ('employe2', TRUE, NOW()),
    ('admin', TRUE, NOW());

-- ============================================================================
-- LOG DE CREATION
-- ============================================================================

INSERT IGNORE INTO admin_audit (
    admin_user,
    action,
    target_user,
    details,
    ip_address
) VALUES (
    'system',
    'bulk_user_creation',
    'testuser,employe1,employe2,admin',
    'Initial user setup for testing',
    '127.0.0.1'
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 'Utilisateurs créés:' as Status;
SELECT username, attribute, value FROM radcheck WHERE attribute = 'User-Password';

SELECT '' as Status;
SELECT 'Statut des utilisateurs:' as Status;
SELECT username, active, created_at FROM user_status;

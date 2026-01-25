# PHP Admin - Interface d'Administration RADIUS

## 📁 Structure du projet

```
php-admin/
├── index.php              # Point d'entrée - Wrapper principal
├── config.php             # Configuration BD et constantes
├── login.php              # Page de connexion
├── logout.php             # Déconnexion
├── pages/
│   ├── dashboard.php      # 🏘️ Tableau de bord (accueil)
│   ├── add_user.php       # ➕ Ajouter un utilisateur
│   ├── list_users.php     # 👥 Lister les utilisateurs
│   ├── edit_user.php      # ✏️ Éditer un utilisateur
│   ├── delete_user.php    # 🗑️ Supprimer un utilisateur
│   ├── audit.php          # 📄 Journal d'audit
│   └── system.php         # ⚙️ Paramètres système
├── logs/
│   └── admin.log          # Journaux d'activité
└── README.md              # Ce fichier
```

## 📋 Pages disponibles

### 1. **Dashboard** (`pages/dashboard.php`)
   - Affichage du nombre d'utilisateurs
   - Nombre de groupes d'accès
   - Actions rapides
   - Informations système

### 2. **Ajouter Utilisateur** (`pages/add_user.php`)
   - Formulaire de création d'utilisateur
   - Validation du mot de passe
   - Vérification de l'unicité

### 3. **Lister Utilisateurs** (`pages/list_users.php`)
   - Tableau de tous les utilisateurs
   - Actions: Éditer, Supprimer
   - Recherche et filtrage

### 4. **Éditer Utilisateur** (`pages/edit_user.php`)
   - Modification du mot de passe
   - Vérification du mot de passe actuel
   - Confirmation obligatoire

### 5. **Supprimer Utilisateur** (`pages/delete_user.php`)
   - Confirmation avant suppression
   - Suppression de tous les enregistrements associés
   - Journal d'audit

### 6. **Journal d'Audit** (`pages/audit.php`)
   - Historique de toutes les actions
   - Dernières 100 entrées
   - Coloration par type (création, modification, suppression)

### 7. **Paramètres Système** (`pages/system.php`)
   - Version PHP
   - Statut de la base de données
   - Extensions PHP requis
   - Information sécurité

## 🔐 Authentification

- Login: `php-admin/login.php`
- Logout: `php-admin/logout.php`
- Session sécurisée en PHP
- Vérification de l'authentification sur `index.php`

## 📄 Configuration

### `config.php`

```php
// Base de données
DB_HOST = 'localhost'
DB_USER = 'radius'
DB_PASS = 'password'
DB_NAME = 'radius'

// Application
APP_TITLE = 'RADIUS Admin'
MIN_PASSWORD_LENGTH = 8
```

## 👥 Utilisation

### Accéder à l'interface

```
http://localhost/php-admin/
```

### Créer un utilisateur

1. Aller sur "Ajouter Utilisateur"
2. Entrer nom d'utilisateur et mot de passe
3. Valider
4. L'utilisateur peut maintenant se connecter au Wi-Fi Enterprise

### Modifier un mot de passe

1. Aller sur "Lister les utilisateurs"
2. Cliquer sur "Éditer" pour l'utilisateur
3. Entrer l'ancien et le nouveau mot de passe
4. Enregistrer

### Supprimer un utilisateur

1. Aller sur "Lister les utilisateurs"
2. Cliquer sur "Supprimer" pour l'utilisateur
3. Confirmer la suppression
4. L'utilisateur ne peut plus se connecter

## 📄 Logs

Tous les accès et modifications sont enregistrés dans `logs/admin.log`:

```
[2026-01-25 14:30:45] INFO: user_created - alice (Nouvel utilisateur créé)
[2026-01-25 14:31:12] INFO: user_modified - alice (Mot de passe modifié)
[2026-01-25 14:32:00] WARNING: user_deleted - alice (Utilisateur supprimé)
```

## 🔐 Sécurité

- 🔓 Authentification obligatoire
- 🔎 Validation de tous les entrées
- 📄 Journalisation complète
- 🔑 Mots de passe chiffrés en base
- 🚫 Protection CSRF
- 🚫 Injection SQL prévenue (PreparedStatements)

## 🔢 Navigation par l'URL

```
?action=dashboard   # Page d'accueil
?action=add         # Ajouter utilisateur
?action=list        # Lister utilisateurs
?action=edit&user=  # Éditer utilisateur
?action=delete&user=# Supprimer utilisateur
?action=audit       # Journal d'audit
?action=system      # Paramètres système
```

## 🚘 Troubleshooting

### "Erreur de connexion à la BD"
- Vérifier les identifiants dans `config.php`
- Vérifier que le serveur MySQL est lancé
- Vérifier les permissions utilisateur

### "Session expirée"
- Recharger la page de connexion
- Vérifier que les cookies sont activés

### "Extension PDO manquante"
- Installer l'extension PHP PDO
- Relancer le serveur web

## 📓 Pré-requis

- PHP 7.4+
- MySQL 5.7+ (ou MariaDB 10.3+)
- FreeRADIUS avec base MySQL
- Extensions PHP: PDO, PDO-MySQL, JSON, Session

## 📆 Fichiers importants

- `index.php` - Dispatcher principal
- `config.php` - Configuration globale
- `pages/*.php` - Pages métier
- `logs/admin.log` - Journal d'audit

## 📂 Proximités

- [FreeRADIUS](https://freeradius.org/)
- [PHP PDO](https://www.php.net/manual/en/book.pdo.php)
- [MySQL](https://www.mysql.com/)

---

**Version:** 1.0  
**Dernière mise à jour:** 25 janvier 2026  
**Auteur:** GroupeNani

# Architecture du NAS Samba sur Raspberry Pi 5

Ce document décrit l'architecture complète du système NAS basé sur Samba.

## Vue d'ensemble du système

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Réseau Local (LAN)                              │
│                   192.168.1.0/24 (exemple)                           │
└────────────┬────────────────────────────────────┬────────────────────┘
             │                                    │
    ┌────────▼────────┐                 ┌────────▼────────┐
    │  Client Windows │                 │   Client macOS  │
    │   \\raspinas    │                 │  smb://raspinas │
    └─────────────────┘                 └─────────────────┘
                       │                │
                ┌──────▼────────────────▼──────┐
                │   Client Linux / Autre       │
                │    smb://raspinas            │
                └──────────┬───────────────────┘
                           │
        ┌──────────────────▼───────────────────┐
        │      Raspberry Pi 5 - NAS Server     │
        │        IP: 192.168.1.100             │
        │        Hostname: raspinas            │
        │                                      │
        │  ┌────────────────────────────────┐  │
        │  │   Raspberry Pi OS (64-bit)     │  │
        │  │      Kernel Linux 6.x          │  │
        │  └────────────┬───────────────────┘  │
        │               │                      │
        │  ┌────────────▼───────────────────┐  │
        │  │      Serveur Samba 4.x         │  │
        │  │   Processus: smbd, nmbd        │  │
        │  │   Ports: 139 (NetBIOS)         │  │
        │  │          445 (SMB/CIFS)        │  │
        │  └────────────┬───────────────────┘  │
        │               │                      │
        │  ┌────────────▼───────────────────┐  │
        │  │   Gestion des partages         │  │
        │  │   /etc/samba/smb.conf          │  │
        │  │                                │  │
        │  │   - [Partage] (Public)         │  │
        │  │   - [Private] (Authentifié)    │  │
        │  │   - [Media]   (Optionnel)      │  │
        │  └────────────┬───────────────────┘  │
        │               │                      │
        │  ┌────────────▼───────────────────┐  │
        │  │   Système de fichiers          │  │
        │  │                                │  │
        │  │   /mnt/nas/                    │  │
        │  │   ├── partage/  (0777)         │  │
        │  │   ├── private/  (0770)         │  │
        │  │   └── media/    (0775)         │  │
        │  └────────────┬───────────────────┘  │
        │               │                      │
        └───────────────┼──────────────────────┘
                        │
                ┌───────▼────────┐
                │ Disque externe │
                │   USB 3.0      │
                │  /dev/sda1     │
                │   (ext4)       │
                └────────────────┘
```

## Flux de connexion

### 1. Connexion client

```
Client (Windows/macOS/Linux)
        │
        ├─> Résolution DNS/NetBIOS (raspinas → 192.168.1.100)
        │
        ├─> Connexion TCP sur port 445 (SMB)
        │   ou port 139 (NetBIOS)
        │
        └─> Handshake SMB
            │
            ├─> [SI partage public]
            │   └─> Accès immédiat (guest ok = yes)
            │
            └─> [SI partage privé]
                └─> Demande authentification
                    │
                    ├─> Vérification utilisateur (pdbedit)
                    │
                    └─> [SI authentifié]
                        └─> Accès au partage
```

### 2. Gestion des permissions

```
Requête d'accès fichier
        │
        ├─> Vérification permissions Unix
        │   (rwxrwxrwx ou rwxrwx---)
        │
        ├─> Vérification permissions Samba
        │   (valid users, write list, read list)
        │
        ├─> Application des masques
        │   (create mask, directory mask)
        │
        └─> [SI autorisé]
            └─> Accès accordé
```

## Composants du système

### 1. Services Samba

| Service | Description | Port | Fonction |
|---------|-------------|------|----------|
| **smbd** | Serveur SMB principal | 445 | Gestion des partages de fichiers |
| **nmbd** | Serveur NetBIOS | 137-139 | Résolution de noms NetBIOS |

### 2. Fichiers de configuration

| Fichier | Description | Rôle |
|---------|-------------|------|
| `/etc/samba/smb.conf` | Configuration principale | Définit les partages et paramètres globaux |
| `/var/lib/samba/private/passdb.tdb` | Base de données utilisateurs | Stocke les mots de passe Samba |
| `/etc/fstab` | Configuration montage | Monte automatiquement le disque externe |

### 3. Structure des répertoires

```
/mnt/nas/                    # Point de montage principal
├── partage/                 # Partage public
│   ├── Documents/
│   ├── Photos/
│   └── Téléchargements/
├── private/                 # Partage privé
│   ├── Confidentiels/
│   └── Personnel/
└── media/                   # Partage multimédia (optionnel)
    ├── Musique/
    ├── Vidéos/
    └── Photos/
```

## Flux de données

### Écriture de fichier

```
Client                Samba Server           Système de fichiers
  │                        │                         │
  ├──── PUT fichier ──────>│                         │
  │                        ├── Vérif. permissions ──>│
  │                        │                         │
  │                        ├── Créer fichier ───────>│
  │                        │                         │
  │                        │<─── Confirmé ───────────┤
  │<─── ACK ───────────────┤                         │
  │                        │                         │
  ├──── Données ──────────>│                         │
  │                        ├── Écrire données ──────>│
  │                        │                         │
  │                        │<─── Écrit ──────────────┤
  │<─── Succès ────────────┤                         │
```

### Lecture de fichier

```
Client                Samba Server           Système de fichiers
  │                        │                         │
  ├──── GET fichier ──────>│                         │
  │                        ├── Vérif. permissions ──>│
  │                        │                         │
  │                        ├── Lire fichier ────────>│
  │                        │                         │
  │                        │<─── Données ────────────┤
  │<─── Données ───────────┤                         │
  │                        │                         │
  │<─── EOF ───────────────┤                         │
```

## Sécurité

### Niveaux de sécurité

```
┌─────────────────────────────────────────────────────┐
│              Niveau 1 : Réseau                      │
│  - Pare-feu UFW (optionnel)                         │
│  - Filtrage IP (hosts allow/deny)                   │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│         Niveau 2 : Authentification Samba           │
│  - Mode security = user                             │
│  - Utilisateurs Samba (smbpasswd)                   │
│  - Groupes Unix (@users)                            │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│       Niveau 3 : Permissions fichiers Unix          │
│  - Propriétaire/Groupe (chown)                      │
│  - Permissions (chmod)                              │
│  - ACL (setfacl - optionnel)                        │
└─────────────────────────────────────────────────────┘
```

### Isolation des partages

```
┌────────────────────────────────────────────┐
│           Partage PUBLIC                   │
│   - Accès : Guest OK                       │
│   - Permissions : 0777 (rwxrwxrwx)         │
│   - Utilisateur : nobody                   │
│   - Usage : Fichiers temporaires           │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│          Partage PRIVÉ                     │
│   - Accès : Authentification requise       │
│   - Permissions : 0770 (rwxrwx---)         │
│   - Groupe : users                         │
│   - Usage : Données sensibles              │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│          Partage PERSONNEL [homes]         │
│   - Accès : Utilisateur propriétaire       │
│   - Permissions : 0700 (rwx------)         │
│   - Utilisateur : %S (utilisateur actuel)  │
│   - Usage : Dossier personnel              │
└────────────────────────────────────────────┘
```

## Performance

### Optimisations réseau

```
Configuration Samba
        │
        ├─> use sendfile = true
        │   └─> Transfert direct kernel → réseau
        │       (pas de copie en userspace)
        │
        ├─> read raw / write raw = yes
        │   └─> Lecture/écriture brute sans traitement
        │
        ├─> aio read/write size
        │   └─> I/O asynchrones pour meilleures perfs
        │
        └─> socket options (déprécié Samba 4.x)
            └─> TCP_NODELAY, buffers augmentés
```

### Bottlenecks possibles

```
Client ──[Ethernet/WiFi]──> Raspberry Pi ──[USB 3.0]──> Disque externe

Vitesses théoriques :
├─ Ethernet Gigabit : 125 MB/s (1000 Mbps)
├─ WiFi 802.11ac    : 40-80 MB/s
├─ USB 3.0          : 300-400 MB/s
└─ Disque HDD       : 80-150 MB/s
   Disque SSD       : 200-500 MB/s

Vitesses réelles attendues :
└─ Ethernet + HDD : 80-100 MB/s
   WiFi + HDD     : 20-40 MB/s
```

## Surveillance

### Points de monitoring

```
┌──────────────────────────────────────────┐
│     Système (htop, vcgencmd)             │
│  - CPU : < 80% en transfert              │
│  - RAM : ~500 MB pour Samba              │
│  - Température : < 70°C                  │
└──────────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│     Services (systemctl status)           │
│  - smbd : active (running)                │
│  - nmbd : active (running)                │
└──────────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│     Connexions (smbstatus)                │
│  - Utilisateurs connectés                 │
│  - Fichiers verrouillés                   │
│  - Partages actifs                        │
└──────────────────────────────────────────┘
             │
┌────────────▼──────────────────────────────┐
│     Logs (/var/log/samba/)                │
│  - Erreurs d'authentification             │
│  - Problèmes de connexion                 │
│  - Accès refusés                          │
└──────────────────────────────────────────┘
```

## Maintenance

### Tâches régulières

| Fréquence | Tâche | Commande |
|-----------|-------|----------|
| **Quotidien** | Vérifier espace disque | `df -h /mnt/nas` |
| **Hebdomadaire** | Vérifier logs | `sudo journalctl -u smbd -since "1 week ago"` |
| **Hebdomadaire** | Vérifier température | `vcgencmd measure_temp` |
| **Mensuel** | Mise à jour système | `sudo apt update && sudo apt upgrade` |
| **Mensuel** | Nettoyer logs | `sudo journalctl --vacuum-time=30d` |
| **Trimestriel** | Vérifier disque | `sudo fsck /dev/sda1` (à faire hors ligne) |

### Sauvegarde

```
┌────────────────────────────────────┐
│      Données NAS (/mnt/nas)        │
└────────────┬───────────────────────┘
             │
    ┌────────▼────────┐
    │  Stratégie 3-2-1 │
    └────────┬─────────┘
             │
    ┌────────▼────────────────────────┐
    │  3 copies des données           │
    │  ├─ 1. Originale (NAS)          │
    │  ├─ 2. Backup local (disque)    │
    │  └─ 3. Backup distant (cloud)   │
    │                                 │
    │  2 supports différents          │
    │  ├─ HDD externe                 │
    │  └─ Cloud / autre NAS           │
    │                                 │
    │  1 copie hors site              │
    │  └─ Cloud ou site distant       │
    └─────────────────────────────────┘
```

## Dépannage - Arbre de décision

```
Problème de connexion
        │
        ├─> Peut-on pinguer le Pi ?
        │   ├─[NON]─> Problème réseau
        │   │         - Vérifier câble
        │   │         - Vérifier switch
        │   │         - Vérifier IP
        │   │
        │   └─[OUI]─> Samba répond-il ?
        │             │
        │             ├─[NON]─> Service arrêté ?
        │             │         - systemctl status smbd
        │             │         - systemctl start smbd
        │             │
        │             └─[OUI]─> Problème authentification ?
        │                       │
        │                       ├─[OUI]─> Mot de passe correct ?
        │                       │         - smbpasswd -a user
        │                       │         - pdbedit -L
        │                       │
        │                       └─[NON]─> Permissions fichiers ?
        │                                 - ls -la /mnt/nas
        │                                 - chmod/chown
```

## Évolution du système

### Extensions possibles

1. **Accès distant sécurisé**
   - VPN (WireGuard, OpenVPN)
   - Reverse proxy avec HTTPS
   - Tailscale pour simplifier

2. **Redondance**
   - RAID 1 avec deux disques
   - Sauvegarde automatique rsync
   - Réplication vers second Pi

3. **Services additionnels**
   - Serveur multimédia (Plex, Jellyfin)
   - Serveur de fichiers FTP
   - Synchronisation cloud (NextCloud)
   - Serveur de téléchargement (Transmission, qBittorrent)

4. **Monitoring avancé**
   - Grafana + Prometheus
   - Netdata
   - Notifications par email/SMS

---

**Version** : 1.0  
**Dernière mise à jour** : Octobre 2025  
**Raspberry Pi** : Modèle 5

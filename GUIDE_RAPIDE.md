# Guide Rapide : Installation NAS Samba sur Raspberry Pi 5

Ce guide fournit les commandes essentielles pour installer rapidement un serveur NAS avec Samba sur Raspberry Pi 5.

## Installation rapide (10 minutes)

### Étape 1 : Mise à jour du système
```bash
sudo apt update && sudo apt upgrade -y
```

### Étape 2 : Installation de Samba
```bash
sudo apt install samba samba-common-bin -y
```

### Étape 3 : Préparation du stockage
```bash
# Créer le point de montage
sudo mkdir -p /mnt/nas/partage

# Définir les permissions
sudo chown -R nobody:nogroup /mnt/nas/partage
sudo chmod -R 0777 /mnt/nas/partage
```

### Étape 4 : Configuration de Samba
```bash
# Sauvegarder la configuration originale
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Éditer la configuration
sudo nano /etc/samba/smb.conf
```

Ajouter à la fin du fichier :
```ini
[Partage]
   comment = Partage NAS
   path = /mnt/nas/partage
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0777
   directory mask = 0777
```

### Étape 5 : Redémarrer Samba
```bash
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
```

### Étape 6 : Tester l'accès
Sur Windows : `\\IP_DU_RASPBERRY\Partage`  
Sur macOS : `smb://IP_DU_RASPBERRY/Partage`  
Sur Linux : `smb://IP_DU_RASPBERRY/Partage`

## Commandes utiles

### Vérifier le statut
```bash
sudo systemctl status smbd
```

### Voir les connexions actives
```bash
sudo smbstatus
```

### Tester la configuration
```bash
testparm
```

### Voir l'adresse IP
```bash
hostname -I
```

### Redémarrer Samba
```bash
sudo systemctl restart smbd nmbd
```

## Créer un utilisateur sécurisé

```bash
# Créer l'utilisateur système
sudo adduser nasuser

# Créer le mot de passe Samba
sudo smbpasswd -a nasuser

# Activer l'utilisateur
sudo smbpasswd -e nasuser
```

## Dépannage rapide

### Samba ne démarre pas
```bash
testparm
sudo journalctl -u smbd -n 50
```

### Impossible de se connecter
```bash
# Vérifier les ports
sudo netstat -tlnp | grep -E '(139|445)'

# Autoriser dans le pare-feu
sudo ufw allow Samba
```

### Réinitialiser les permissions
```bash
sudo chmod -R 0777 /mnt/nas/partage
sudo systemctl restart smbd
```

## Architecture du système

```
Raspberry Pi 5
    |
    |-- Raspberry Pi OS (64-bit)
    |
    |-- Samba Server
    |       |-- Port 139 (NetBIOS)
    |       |-- Port 445 (SMB/CIFS)
    |
    |-- Stockage
            |-- /mnt/nas/partage (Public)
            |-- /mnt/nas/private (Privé)
```

## Checklist de vérification

- [ ] Système à jour (`sudo apt update && sudo apt upgrade`)
- [ ] Samba installé (`samba --version`)
- [ ] Dossiers créés (`ls /mnt/nas`)
- [ ] Configuration testée (`testparm`)
- [ ] Services démarrés (`systemctl status smbd`)
- [ ] Accès réseau testé (depuis un autre ordinateur)
- [ ] Utilisateurs configurés (si nécessaire)
- [ ] Disque externe monté (si utilisé)

## Performance attendue

- **Vitesse de transfert** : 80-100 MB/s (avec Ethernet Gigabit)
- **Vitesse de transfert** : 20-40 MB/s (avec WiFi)
- **Latence** : < 10 ms sur le réseau local
- **Capacité** : Limitée par le disque externe

## Prochaines étapes

Pour une configuration plus avancée, consultez le [README.md](README.md) complet qui inclut :
- Configuration avancée de Samba
- Gestion détaillée des utilisateurs
- Optimisations de performance
- Sauvegarde automatique
- Monitoring et logs
- Dépannage approfondi

---

**Durée d'installation** : 10-15 minutes  
**Niveau** : Débutant à intermédiaire  
**Support** : Raspberry Pi 5 avec Raspberry Pi OS

# Mini-projet : Installation NAS via Samba sur Raspberry Pi 5

## Description du projet

Ce mini-projet décrit l'installation et la configuration d'un serveur NAS (Network Attached Storage) utilisant Samba sur un Raspberry Pi 5. Samba permet de partager des fichiers et des dossiers sur un réseau local, rendant le Raspberry Pi accessible depuis des ordinateurs Windows, macOS et Linux.

## Table des matières

1. [Prérequis](#prérequis)
2. [Matériel nécessaire](#matériel-nécessaire)
3. [Installation du système](#installation-du-système)
4. [Installation de Samba](#installation-de-samba)
5. [Configuration du NAS](#configuration-du-nas)
6. [Gestion des utilisateurs](#gestion-des-utilisateurs)
7. [Montage des partages](#montage-des-partages)
8. [Tests et vérification](#tests-et-vérification)
9. [Dépannage](#dépannage)
10. [Optimisations](#optimisations)

## Prérequis

- Raspberry Pi 5 avec au moins 4 GB de RAM (recommandé 8 GB)
- Carte microSD (minimum 16 GB, recommandé 32 GB ou plus)
- Disque dur externe ou clé USB pour le stockage NAS
- Connexion Internet pour les téléchargements
- Accès au réseau local (Ethernet recommandé pour de meilleures performances)
- Connaissances de base en ligne de commande Linux

## Matériel nécessaire

- **Raspberry Pi 5** (4 GB ou 8 GB)
- **Alimentation officielle** (5V/5A USB-C)
- **Carte microSD** avec Raspberry Pi OS
- **Disque dur externe** (USB 3.0 recommandé)
- **Câble Ethernet** (optionnel mais recommandé)
- **Boîtier** avec ventilation (recommandé pour le refroidissement)

## Installation du système

### 1. Installation de Raspberry Pi OS

```bash
# Télécharger Raspberry Pi Imager depuis le site officiel
# Installer Raspberry Pi OS Lite (64-bit) pour de meilleures performances

# Après le premier démarrage, mettre à jour le système
sudo apt update
sudo apt upgrade -y
```

### 2. Configuration initiale

```bash
# Configurer le Raspberry Pi
sudo raspi-config

# Dans le menu :
# - Définir le hostname
# - Activer SSH pour l'accès distant
# - Étendre le système de fichiers
# - Configurer la locale et le fuseau horaire
```

### 3. Configuration réseau

```bash
# Vérifier l'adresse IP
ip addr show

# Pour une IP statique, éditer la configuration
sudo nano /etc/dhcpcd.conf

# Ajouter à la fin du fichier :
# interface eth0
# static ip_address=192.168.1.100/24
# static routers=192.168.1.1
# static domain_name_servers=192.168.1.1 8.8.8.8
```

## Installation de Samba

### 1. Installation des paquets

```bash
# Installer Samba et les outils nécessaires
sudo apt install samba samba-common-bin -y

# Vérifier que Samba est installé
samba --version
```

### 2. Préparation du disque de stockage

```bash
# Identifier le disque externe
sudo lsblk

# Créer un point de montage
sudo mkdir -p /mnt/nas

# Formater le disque (ATTENTION : cela efface toutes les données)
# Remplacer /dev/sda1 par votre disque
sudo mkfs.ext4 /dev/sda1

# Obtenir l'UUID du disque
sudo blkid

# Monter le disque automatiquement au démarrage
sudo nano /etc/fstab

# Ajouter la ligne (remplacer UUID par celui obtenu) :
# UUID=votre-uuid-ici /mnt/nas ext4 defaults,nofail 0 2

# Monter le disque
sudo mount -a

# Vérifier le montage
df -h
```

### 3. Configuration des permissions

```bash
# Créer les dossiers de partage
sudo mkdir -p /mnt/nas/partage
sudo mkdir -p /mnt/nas/private

# Définir les permissions
sudo chown -R nobody:nogroup /mnt/nas/partage
sudo chmod -R 0777 /mnt/nas/partage

sudo chown -R root:users /mnt/nas/private
sudo chmod -R 0770 /mnt/nas/private
```

## Configuration du NAS

### 1. Sauvegarde de la configuration par défaut

```bash
# Faire une copie de sauvegarde
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
```

### 2. Configuration de Samba

```bash
# Éditer le fichier de configuration
sudo nano /etc/samba/smb.conf
```

Ajouter à la fin du fichier :

```ini
# Configuration globale
[global]
   workgroup = WORKGROUP
   server string = Raspberry Pi NAS
   netbios name = raspinas
   security = user
   map to guest = bad user
   dns proxy = no
   
   # Performance optimizations
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
   read raw = yes
   write raw = yes
   max xmit = 65535
   dead time = 15
   getwd cache = yes

# Partage public
[Partage]
   comment = Partage public
   path = /mnt/nas/partage
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0777
   directory mask = 0777
   force user = nobody

# Partage privé
[Private]
   comment = Partage privé
   path = /mnt/nas/private
   browseable = yes
   writable = yes
   guest ok = no
   read only = no
   valid users = @users
   create mask = 0770
   directory mask = 0770
   force group = users
```

### 3. Vérification de la configuration

```bash
# Tester la configuration
testparm

# Si pas d'erreurs, redémarrer Samba
sudo systemctl restart smbd
sudo systemctl restart nmbd

# Activer Samba au démarrage
sudo systemctl enable smbd
sudo systemctl enable nmbd

# Vérifier le statut
sudo systemctl status smbd
sudo systemctl status nmbd
```

## Gestion des utilisateurs

### 1. Créer un utilisateur Samba

```bash
# Créer un utilisateur système
sudo adduser nasuser

# Ajouter l'utilisateur au groupe users
sudo usermod -aG users nasuser

# Créer le mot de passe Samba
sudo smbpasswd -a nasuser

# Activer l'utilisateur
sudo smbpasswd -e nasuser
```

### 2. Gérer les utilisateurs existants

```bash
# Lister les utilisateurs Samba
sudo pdbedit -L

# Changer le mot de passe
sudo smbpasswd nasuser

# Désactiver un utilisateur
sudo smbpasswd -d nasuser

# Supprimer un utilisateur
sudo smbpasswd -x nasuser
```

## Montage des partages

### Sur Windows

1. Ouvrir l'Explorateur de fichiers
2. Dans la barre d'adresse, taper : `\\raspinas` ou `\\IP_DU_RASPBERRY`
3. Pour monter en tant que lecteur réseau :
   - Clic droit sur "Ce PC" → "Connecter un lecteur réseau"
   - Choisir une lettre de lecteur
   - Entrer le chemin : `\\raspinas\Partage`

### Sur macOS

1. Finder → Aller → Se connecter au serveur (Cmd+K)
2. Entrer : `smb://raspinas` ou `smb://IP_DU_RASPBERRY`
3. Se connecter avec les identifiants (si nécessaire)

### Sur Linux

```bash
# Installer les outils clients
sudo apt install cifs-utils

# Créer un point de montage
sudo mkdir -p /mnt/partage

# Monter le partage
sudo mount -t cifs //raspinas/Partage /mnt/partage -o username=nasuser,password=votre_mot_de_passe

# Pour un montage automatique, éditer /etc/fstab
sudo nano /etc/fstab

# Ajouter :
# //raspinas/Partage /mnt/partage cifs username=nasuser,password=votre_mot_de_passe,iocharset=utf8 0 0
```

## Tests et vérification

### 1. Tests de connectivité

```bash
# Vérifier que Samba écoute sur les bons ports
sudo netstat -tlnp | grep smbd

# Tester depuis un autre ordinateur
smbclient -L //raspinas -N

# Lister les partages disponibles
smbclient -L //raspinas -U nasuser
```

### 2. Tests de performance

```bash
# Tester la vitesse d'écriture
dd if=/dev/zero of=/mnt/nas/partage/testfile bs=1M count=1024

# Tester la vitesse de lecture
dd if=/mnt/nas/partage/testfile of=/dev/null bs=1M

# Nettoyer le fichier de test
rm /mnt/nas/partage/testfile
```

### 3. Vérification des permissions

```bash
# Vérifier les permissions des dossiers
ls -la /mnt/nas/

# Tester l'accès utilisateur
sudo -u nasuser touch /mnt/nas/private/test.txt
```

## Dépannage

### Problèmes courants

#### Samba ne démarre pas

```bash
# Vérifier les logs
sudo journalctl -u smbd -n 50

# Vérifier la configuration
testparm

# Réinstaller Samba si nécessaire
sudo apt remove --purge samba samba-common-bin
sudo apt install samba samba-common-bin
```

#### Impossible de se connecter

```bash
# Vérifier le pare-feu
sudo ufw status

# Autoriser Samba si nécessaire
sudo ufw allow Samba

# Vérifier que les ports sont ouverts
sudo netstat -tlnp | grep -E '(139|445)'
```

#### Problèmes de permissions

```bash
# Réinitialiser les permissions
sudo chown -R nobody:nogroup /mnt/nas/partage
sudo chmod -R 0777 /mnt/nas/partage

# Redémarrer Samba
sudo systemctl restart smbd
```

#### Performances lentes

```bash
# Vérifier l'utilisation du CPU
top

# Vérifier l'utilisation du disque
iostat -x 1

# Optimiser la configuration Samba (voir section Optimisations)
```

## Optimisations

### 1. Optimisation des performances réseau

```bash
# Éditer la configuration Samba
sudo nano /etc/samba/smb.conf

# Ajouter dans la section [global] :
# min receivefile size = 16384
# use sendfile = true
# aio read size = 16384
# aio write size = 16384
```

### 2. Refroidissement et performances

```bash
# Vérifier la température
vcgencmd measure_temp

# Installer un système de monitoring
sudo apt install lm-sensors
sensors
```

### 3. Sauvegarde automatique

```bash
# Créer un script de sauvegarde
sudo nano /usr/local/bin/backup-nas.sh

# Contenu du script :
#!/bin/bash
# rsync -avz /mnt/nas/private /mnt/backup/

# Rendre le script exécutable
sudo chmod +x /usr/local/bin/backup-nas.sh

# Ajouter une tâche cron
sudo crontab -e

# Exécuter tous les jours à 2h du matin :
# 0 2 * * * /usr/local/bin/backup-nas.sh
```

### 4. Monitoring et logs

```bash
# Vérifier les logs Samba
sudo tail -f /var/log/samba/log.smbd

# Installer un outil de monitoring
sudo apt install htop
```

## Conclusion

Vous disposez maintenant d'un serveur NAS fonctionnel basé sur Samba sur votre Raspberry Pi 5. Ce système permet de partager des fichiers facilement sur votre réseau local avec différents systèmes d'exploitation.

### Recommandations

- **Sécurité** : Utilisez toujours des mots de passe forts pour les utilisateurs Samba
- **Sauvegardes** : Mettez en place une stratégie de sauvegarde régulière
- **Mises à jour** : Maintenez votre système à jour avec `sudo apt update && sudo apt upgrade`
- **Surveillance** : Surveillez régulièrement les performances et les logs
- **Refroidissement** : Assurez-vous que le Raspberry Pi reste à une température acceptable

## Ressources

- [Documentation officielle Samba](https://www.samba.org/samba/docs/)
- [Documentation Raspberry Pi](https://www.raspberrypi.org/documentation/)
- [Forum Raspberry Pi](https://forums.raspberrypi.com/)

---

**Auteur** : Seiha1337  
**Date** : Octobre 2025  
**Raspberry Pi** : Modèle 5
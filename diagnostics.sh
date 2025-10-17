#!/bin/bash
#
# Script de diagnostic pour NAS Samba sur Raspberry Pi 5
# Ce script vérifie l'état du système et identifie les problèmes potentiels
#
# Usage: sudo ./diagnostics.sh
#

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher un titre
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Fonction pour afficher un succès
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Fonction pour afficher une erreur
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Fonction pour afficher un avertissement
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then 
    print_error "Ce script doit être exécuté en tant que root (sudo)"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Diagnostic NAS Samba - Raspberry Pi 5                   ║"
echo "╚════════════════════════════════════════════════════════════╝"

# 1. Informations système
print_header "1. Informations Système"

echo -n "Modèle Raspberry Pi : "
cat /proc/device-tree/model 2>/dev/null || echo "Non disponible"

echo -n "Version OS : "
cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2

echo -n "Kernel : "
uname -r

echo -n "Architecture : "
uname -m

echo -n "Température CPU : "
vcgencmd measure_temp 2>/dev/null || echo "Non disponible"

echo -n "Mémoire disponible : "
free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.0f%% utilisé)\n", $3/1024, $2/1024, $3*100/$2}'

echo -n "Charge système : "
uptime | awk -F'load average:' '{print $2}'

# 2. Vérification de Samba
print_header "2. Installation de Samba"

if command -v samba &> /dev/null; then
    print_success "Samba est installé"
    echo -n "Version : "
    samba --version
else
    print_error "Samba n'est PAS installé"
    echo "Installer avec : sudo apt install samba samba-common-bin"
fi

# 3. Services Samba
print_header "3. État des Services"

if systemctl is-active --quiet smbd; then
    print_success "Service smbd est actif"
else
    print_error "Service smbd n'est PAS actif"
    echo "Démarrer avec : sudo systemctl start smbd"
fi

if systemctl is-active --quiet nmbd; then
    print_success "Service nmbd est actif"
else
    print_error "Service nmbd n'est PAS actif"
    echo "Démarrer avec : sudo systemctl start nmbd"
fi

if systemctl is-enabled --quiet smbd; then
    print_success "Service smbd activé au démarrage"
else
    print_warning "Service smbd non activé au démarrage"
    echo "Activer avec : sudo systemctl enable smbd"
fi

# 4. Configuration Samba
print_header "4. Configuration Samba"

if [ -f /etc/samba/smb.conf ]; then
    print_success "Fichier de configuration trouvé : /etc/samba/smb.conf"
    
    echo -n "Test de la configuration : "
    if testparm -s &> /dev/null; then
        print_success "Configuration valide"
    else
        print_error "Erreurs dans la configuration"
        echo "Vérifier avec : testparm"
    fi
else
    print_error "Fichier de configuration introuvable"
fi

# 5. Ports réseau
print_header "5. Ports Réseau"

if netstat -tlnp 2>/dev/null | grep -q ":139"; then
    print_success "Port 139 (NetBIOS) en écoute"
else
    print_error "Port 139 n'est PAS en écoute"
fi

if netstat -tlnp 2>/dev/null | grep -q ":445"; then
    print_success "Port 445 (SMB) en écoute"
else
    print_error "Port 445 n'est PAS en écoute"
fi

# 6. Adresse réseau
print_header "6. Configuration Réseau"

echo "Adresse(s) IP :"
hostname -I | tr ' ' '\n' | grep -v '^$'

echo -n "Nom d'hôte : "
hostname

echo -n "Nom NetBIOS : "
grep "netbios name" /etc/samba/smb.conf 2>/dev/null | awk '{print $3}' || echo "Non configuré"

# 7. Partages configurés
print_header "7. Partages Configurés"

if command -v testparm &> /dev/null; then
    echo "Liste des partages :"
    testparm -s 2>/dev/null | grep "^\[" | grep -v "\[global\]" || echo "Aucun partage configuré"
fi

# 8. Vérification des dossiers de partage
print_header "8. Dossiers de Partage"

# Rechercher les chemins dans smb.conf
if [ -f /etc/samba/smb.conf ]; then
    SHARE_PATHS=$(grep "path = " /etc/samba/smb.conf | awk '{print $3}')
    
    for path in $SHARE_PATHS; do
        if [ -d "$path" ]; then
            print_success "Dossier existe : $path"
            ls -ld "$path"
        else
            print_error "Dossier manquant : $path"
            echo "Créer avec : sudo mkdir -p $path"
        fi
    done
fi

# 9. Utilisateurs Samba
print_header "9. Utilisateurs Samba"

if command -v pdbedit &> /dev/null; then
    USER_COUNT=$(pdbedit -L 2>/dev/null | wc -l)
    echo "Nombre d'utilisateurs : $USER_COUNT"
    if [ $USER_COUNT -gt 0 ]; then
        echo "Liste des utilisateurs :"
        pdbedit -L 2>/dev/null || echo "Erreur lors de la liste des utilisateurs"
    fi
else
    print_warning "Commande pdbedit non disponible"
fi

# 10. Connexions actives
print_header "10. Connexions Actives"

if command -v smbstatus &> /dev/null; then
    CONNECTIONS=$(smbstatus -b 2>/dev/null | grep -v "^$" | wc -l)
    if [ $CONNECTIONS -gt 3 ]; then
        print_success "Connexions actives détectées"
        smbstatus -b 2>/dev/null
    else
        print_warning "Aucune connexion active"
    fi
else
    print_warning "Commande smbstatus non disponible"
fi

# 11. Espace disque
print_header "11. Espace Disque"

df -h | grep -E "Filesystem|/mnt|/media" || df -h /

# 12. Pare-feu
print_header "12. Pare-feu"

if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | grep "Status:" | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        print_warning "Pare-feu UFW est actif"
        echo "Vérifier les règles pour Samba (ports 139, 445)"
        ufw status | grep -E "139|445|Samba" || print_warning "Aucune règle Samba trouvée"
    else
        print_success "Pare-feu UFW est inactif"
    fi
else
    echo "UFW non installé"
fi

# 13. Logs récents
print_header "13. Logs Récents (5 dernières lignes)"

if [ -f /var/log/samba/log.smbd ]; then
    echo "Logs smbd :"
    tail -n 5 /var/log/samba/log.smbd
else
    print_warning "Logs smbd non trouvés"
fi

# 14. Performance
print_header "14. Performance"

echo "Processus utilisant le plus de CPU :"
ps aux --sort=-%cpu | head -n 6

echo -e "\nProcessus utilisant le plus de mémoire :"
ps aux --sort=-%mem | head -n 6

# Résumé
print_header "15. Résumé et Recommandations"

ISSUES=0

# Vérifications critiques
if ! command -v samba &> /dev/null; then
    print_error "Samba n'est pas installé"
    ISSUES=$((ISSUES+1))
fi

if ! systemctl is-active --quiet smbd; then
    print_error "Service smbd n'est pas actif"
    ISSUES=$((ISSUES+1))
fi

if ! netstat -tlnp 2>/dev/null | grep -q ":445"; then
    print_error "Port SMB (445) n'est pas en écoute"
    ISSUES=$((ISSUES+1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "\n${GREEN}✓ Aucun problème critique détecté${NC}"
    echo "Votre serveur NAS Samba semble être correctement configuré."
else
    echo -e "\n${RED}✗ $ISSUES problème(s) critique(s) détecté(s)${NC}"
    echo "Consultez les erreurs ci-dessus et corrigez-les."
fi

echo -e "\n${BLUE}Commandes utiles :${NC}"
echo "  - Tester la configuration : testparm"
echo "  - Redémarrer Samba : sudo systemctl restart smbd nmbd"
echo "  - Voir les logs : sudo journalctl -u smbd -n 50"
echo "  - Voir les connexions : sudo smbstatus"
echo "  - Tester l'accès : smbclient -L //localhost -N"

echo -e "\n${BLUE}Accès au partage :${NC}"
IP=$(hostname -I | awk '{print $1}')
echo "  - Windows : \\\\$IP\\Partage"
echo "  - macOS   : smb://$IP/Partage"
echo "  - Linux   : smb://$IP/Partage"

echo -e "\nDiagnostic terminé - $(date)"

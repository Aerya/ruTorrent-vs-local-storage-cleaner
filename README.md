Script BASH pour nettoyer les éléments orphelins dans DOWNLOAD_DIR de ruTorrent en se basant sur les .torrent actifs (info->name dans SESSION_DIR)

## Configuration
Dossier (caché) de session
SESSION_DIR="/mnt/user/appdata/rutorrent-direct/rtorrent/.session"
Dossier de téléchargements (globaux ou Complétés)
DOWNLOAD_DIR="/mnt/bittorrent/rutorrent-direct"

Dossier pour les logs
LOG_DIR="/mnt/user/appdata/"
Nom du fichier de logs
LOG_FILE="$LOG_DIR/cleanup.log"

Par défaut, fait un tests à blanc
DRY_RUN=true   # passe à false pour supprimer réellement
Statistiques ou non en console
DEBUG=1        # 0 = silencieux ; 1 = affiche quelques stats

Permet de ne pas supprimer les dossiers et fichiers cachés qui servent notamment à des applications tiers de synchronisation etc
SKIP_HIDDEN=true  # ignore .stfolder, @eaDir, etc.

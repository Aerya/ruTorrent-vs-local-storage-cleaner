#!/bin/bash
# Nettoie les éléments orphelins dans DOWNLOAD_DIR en se basant sur les .torrent actifs (info->name dans SESSION_DIR)

set -uo pipefail  # pas de -e pour éviter les sorties silencieuses

# ===== CONFIG =====
SESSION_DIR="/mnt/user/appdata/rutorrent-direct/rtorrent/.session"
DOWNLOAD_DIR="/mnt/bittorrent/rutorrent-direct"

LOG_DIR="/mnt/user/appdata/"
LOG_FILE="$LOG_DIR/cleanup.log"

DRY_RUN=true   # passe à false pour supprimer réellement
DEBUG=1        # 0 = silencieux ; 1 = affiche quelques stats

SKIP_HIDDEN=true  # ignore .stfolder, @eaDir, etc.

mkdir -p "$LOG_DIR"

log() {
  # Toujours réussir même si le log-file est indisponible
  printf "[%s] %s\n" "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >/dev/null || true
}

normalize() {
  local s="$1"
  if command -v iconv >/dev/null 2>&1; then
    s=$(printf "%s" "$s" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf "%s" "$s")
  fi
  s=$(printf "%s" "$s" | tr '[:upper:]' '[:lower:]')
  printf "%s" "$s" | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g; s/ +/ /g'
}

should_skip() {
  local base="$1"
  if [[ "$SKIP_HIDDEN" == "true" ]]; then
    case "$base" in
      .*|@eaDir|lost+found|.stfolder|.stversions|.AppleDouble|Thumbs.db|.DS_Store) return 0 ;;
    esac
  fi
  return 1
}

log "Démarrage – session: $SESSION_DIR / downloads: $DOWNLOAD_DIR (dry-run=$DRY_RUN)"

# ===== Extraction des info->name depuis les .torrent =====
mapfile -t TORRENT_NAMES < <(
python3 - "$SESSION_DIR" <<'PYCODE'
import os, sys

def bdecode(data, i=0):
    t = data[i:i+1]
    if t == b'i':
        j = data.index(b'e', i)
        return int(data[i+1:j]), j+1
    if t == b'l':
        lst, i = [], i+1
        while data[i:i+1] != b'e':
            v, i = bdecode(data, i); lst.append(v)
        return lst, i+1
    if t == b'd':
        dct, i = {}, i+1
        while data[i:i+1] != b'e':
            k, i = bdecode(data, i)
            v, i = bdecode(data, i)
            dct[k] = v
        return dct, i+1
    j = data.index(b':', i)
    ln = int(data[i:j])
    j += 1
    return data[j:j+ln], j+ln

root = sys.argv[1]
names = set()
for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith('.torrent'):
            continue
        p = os.path.join(dirpath, f)
        try:
            with open(p, 'rb') as fh:
                data = fh.read()
            obj, _ = bdecode(data)
            if isinstance(obj, dict) and b'info' in obj and isinstance(obj[b'info'], dict):
                name = obj[b'info'].get(b'name')
                if isinstance(name, (bytes, bytearray)):
                    names.add(name.decode('utf-8', 'ignore'))
        except Exception:
            pass
for n in sorted(names):
    print(n)
PYCODE
) || TORRENT_NAMES=()

declare -A NORM_TORRENT_NAMES=()
for n in "${TORRENT_NAMES[@]}"; do
  norm=$(normalize "$n")
  [[ -n "$norm" ]] && NORM_TORRENT_NAMES["$norm"]=1
done

if (( DEBUG )); then
  cnt_torr=$(find "$SESSION_DIR" -type f -name '*.torrent' | wc -l)
  log "Fichiers .torrent détectés: $cnt_torr ; Noms info->name uniques: ${#NORM_TORRENT_NAMES[@]}"
fi

if [[ ${#NORM_TORRENT_NAMES[@]} -eq 0 ]]; then
  log "Aucun nom extrait depuis les .torrent → vérifie SESSION_DIR."
  exit 2
fi

# ===== Scan du dossier de téléchargement, profondeur 1 =====
orphan_count=0

while IFS= read -r -d '' ITEM; do
  base="${ITEM##*/}"
  if should_skip "$base"; then
    continue
  fi
  norm_base=$(normalize "$base")
  if [[ -z "${NORM_TORRENT_NAMES[$norm_base]:-}" ]]; then
    log "Orphelin : $ITEM"
    ((orphan_count++))
    if [[ "$DRY_RUN" == "false" ]]; then
      rm -rf -- "$ITEM" 2>/dev/null || log "Échec suppression: $ITEM"
    fi
  fi
done < <(find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -print0)

log "Terminé – orphelins détectés: $orphan_count (dry-run=$DRY_RUN)"
echo "Orphelins: $orphan_count"

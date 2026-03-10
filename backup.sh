#!/bin/bash
set -e

# --- LOGGING (alle Ausgaben in Logdatei + Konsole) ---
exec > >(tee -a "/backup/backup.log") 2>&1

# --- KONFIGURATION ---
BACKUP_BASE_DIR="/backup"
PAPERLESS_DATA_DIR="/paperless_data"
LATEST_LINK="${BACKUP_BASE_DIR}/latest"
RETENTION_DAYS=30

# Container Namen
PG_CONTAINER="paperless-db"
WEBSERVER_CONTAINER="paperless"
PG_USER="paperless"
PG_DB="paperless"

echo "--- Backup Start: $(date) ---"

# 1. Verzeichnis erstellen
DATE_STAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="${BACKUP_BASE_DIR}/${DATE_STAMP}"
mkdir -p "${BACKUP_DIR}"

# 2. Versionsinfos speichern
echo "Speichere Versionen..."
VERSION_FILE="${BACKUP_DIR}/restore_info.txt"
echo "Backup Timestamp: ${DATE_STAMP}" > "${VERSION_FILE}"

# Postgres Version auslesen
PG_VER=$(docker exec "${PG_CONTAINER}" psql -U "${PG_USER}" -d "${PG_DB}" -c "SHOW server_version;" -t | xargs)
echo "PostgreSQL Version: ${PG_VER}" >> "${VERSION_FILE}"

# 3. Datenbank Dump
echo "Erstelle DB Dump..."
docker exec "${PG_CONTAINER}" pg_dump -U "${PG_USER}" -d "${PG_DB}" > "${BACKUP_DIR}/paperless-db.sql"

if [ ! -s "${BACKUP_DIR}/paperless-db.sql" ]; then
    echo "FEHLER: DB Dump ist leer — Backup abgebrochen!"
    rm -rf "${BACKUP_DIR}"
    exit 1
fi

# 4. Paperless Exporter (sichert Dokumente + Manifeste)
# WICHTIG: python3 manage.py ist zwingend erforderlich!
echo "Starte Paperless Exporter..."
docker exec "${WEBSERVER_CONTAINER}" python3 manage.py document_exporter ../export

# 5. Rsync (kopiert exportierte Daten ins Backup, Hardlinks sparen Speicherplatz)
echo "Synchronisiere Dateien..."
LINK_DEST_OPTION=""
if [ -d "${LATEST_LINK}" ]; then
  LINK_DEST_OPTION="--link-dest=${LATEST_LINK}/documents"
fi
rsync -a --delete ${LINK_DEST_OPTION} "${PAPERLESS_DATA_DIR}/export/" "${BACKUP_DIR}/documents/"

# 6. Symlink auf das neueste Backup setzen
ln -snf "${BACKUP_DIR}" "${LATEST_LINK}"

# 7. Aufräumen (alte Backups löschen, || true verhindert Abbruch wenn nichts zu löschen)
echo "Lösche Backups älter als ${RETENTION_DAYS} Tage..."
find "${BACKUP_BASE_DIR}" -maxdepth 1 -type d -not -name "latest" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; || true

echo "--- Backup Fertig: $(date) ---"

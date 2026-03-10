# Paperless-ngx — Synology NAS Setup

Vollständige, deutschsprachige Setup-Anleitung für **Paperless-ngx** auf einem Synology NAS mit 10 Containern, Grafana-Monitoring und automatischem Backup.

---

## 📦 Was ist enthalten?

| Datei | Beschreibung |
|---|---|
| `paperless-anleitung.html` | Komplette Schritt-für-Schritt Anleitung als HTML |
| `docker-compose.yml` | Fertige Compose-Datei für Synology NAS |
| `backup.sh` | Automatisches Backup-Skript |

---

## 🐳 Container-Übersicht

| # | Container | Image | Port | Funktion |
|---|---|---|---|---|
| 1 | `paperless-redis` | valkey/valkey:9 | intern | Message Broker |
| 2 | `paperless-db` | postgres:18 | intern | Datenbank |
| 3 | `paperless` | paperless-ngx:2.20 | 8090 | Hauptanwendung |
| 4 | `paperless-gotenberg` | gotenberg:8 | 3005 | PDF-Konvertierung |
| 5 | `paperless-tika` | apache/tika:3.2.3.0 | intern | Office Dokumente |
| 6 | `paperless-ofelia` | mcuadros/ofelia:0.3 | intern | Cron-Job Scheduler |
| 7 | `paperless-backup-runner` | alpine:3.15 | intern | Automatisches Backup |
| 8 | `paperless-redis-exporter` | redis_exporter:v1.81.0 | intern | Metriken |
| 9 | `paperless-grafana` | grafana/grafana:12.4 | 3001 | Dashboard |
| 10 | `paperless-prometheus` | prom/prometheus:v3.10.0 | intern | Metriken-Sammler |

---

## 🚀 Schnellstart

### 1. Ordner erstellen (SSH)
```bash
mkdir -p /volume1/docker/paperless/{redis,db,data,media,export,consume,grafana,prometheus,scripts,backups}
```

### 2. Grafana Berechtigung setzen
```bash
chown -R 472:472 /volume1/docker/paperless/grafana
chmod -R 775 /volume1/docker/paperless/grafana
```

### 3. prometheus.yml erstellen
Datei: `/volume1/docker/paperless/prometheus/prometheus.yml`
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'paperless-monitoring'
    static_configs:
      - targets: ['paperless-redis-exporter:9121']
```

### 4. .env Datei erstellen
Datei: `/volume1/docker/paperless/.env`
```env
POSTGRES_PASSWORD=SICHERES_PASSWORT_HIER
PAPERLESS_DBPASS=GLEICHES_PASSWORT_WIE_OBEN
PAPERLESS_SECRET_KEY=LANGEN_ZUFAELLIGEN_KEY_HIER
GF_SECURITY_ADMIN_PASSWORD=GRAFANA_PASSWORT_HIER
```
Secret Key generieren:
```bash
openssl rand -base64 50
```

### 5. backup.sh einrichten
```bash
cp backup.sh /volume1/docker/paperless/scripts/backup.sh
chmod +x /volume1/docker/paperless/scripts/backup.sh
```

### 6. docker-compose.yml anpassen
Folgende Werte anpassen (suche nach `← Anpassen bei neuer Instanz`):
- `user: "UID:GID"` → eigene UID ermitteln: `id DEINUSERNAME`
- `USERMAP_UID` → gleiche UID
- `PAPERLESS_ALLOWED_HOSTS` → eigene LAN-IP + Tailscale-IP

### 7. Stack starten
```bash
cd /volume1/docker/paperless
docker compose up -d
```

### 8. Admin-User anlegen
```bash
docker exec -it paperless python3 manage.py createsuperuser
```

---

## 📁 Dateinamens-Format Varianten

In der `docker-compose.yml` kann zwischen 4 Varianten gewählt werden:

| Option | Struktur | Empfehlung |
|---|---|---|
| **A** | `Besitzer/Korrespondent/Jahr/Datum - Titel` | ✅ Empfohlen |
| **B** | `Besitzer/Korrespondent/Dokumententyp/Datum - Titel` | Einfach |
| **C** | `Besitzer/Korrespondent/Dokumententyp/Jahr/Datum - Titel` | Detailliert |
| **D** | `Besitzer/Thema-Tag/Korrespondent/Jahr/Datum - Typ - Titel` | Komplex |

Nach dem Wechsel Renamer ausführen:
```bash
docker exec -it paperless python3 manage.py document_renamer
```

---

## 📊 Grafana einrichten

1. Grafana öffnen: `http://NAS-IP:3001`
2. **Connections → Data sources → Add → Prometheus**
   - URL: `http://paperless-prometheus:9090`
   - Save & test
3. **Dashboards → New → Import → ID: `763`**
4. Profil-Icon → Profile → Preferences → Home Dashboard setzen

---

## 💾 Backup

Das Backup läuft automatisch täglich um **20:10 Uhr** via Ofelia.

**Manuell starten:**
```bash
docker exec paperless-backup-runner /bin/bash /scripts/backup.sh
```

**Log prüfen:**
```bash
cat /volume1/docker/paperless/backups/backup.log
```

**Struktur:**
```
backups/
├── 2024-03-15_20-10-00/
│   ├── paperless-db.sql
│   ├── restore_info.txt
│   └── documents/
├── latest -> 2024-03-15_20-10-00
└── backup.log
```

> ⚠️ Backups älter als 30 Tage werden automatisch gelöscht.  
> ⚠️ Externes Backup zusätzlich empfohlen!

---

## ⚠️ Wichtige Hinweise

- `PAPERLESS_SECRET_KEY` **niemals** nach erstem Start ändern!
- `POSTGRES_PASSWORD` und `PAPERLESS_DBPASS` müssen identisch sein!
- `.env` Datei niemals in Git einchecken (ist in `.gitignore` eingetragen)
- Bei Option D: `tag_name_list` verwenden, nicht `tags`!

---

## 🔗 Links

- [Paperless-ngx Dokumentation](https://docs.paperless-ngx.com/)
- [Paperless-ngx GitHub](https://github.com/paperless-ngx/paperless-ngx)
- [Grafana Redis Dashboard (ID: 763)](https://grafana.com/grafana/dashboards/763)

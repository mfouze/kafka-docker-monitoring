# Vérification des Certificats - Sécurité MirrorMaker 2 Transactis

## Objectif

Établir une procédure complète de vérification et de suivi des certificats TLS utilisés par l'infrastructure Kafka NEMO, Applicatif et MirrorMaker 2.

---

## Pré-requis

- [x] Accès aux serveurs validé (cf. `01-prerequis/inventaire-acces.md`)
- [ ] Emplacement des keystores/truststores identifié
- [ ] Mots de passe des keystores disponibles

---

## Contexte Transactis

**Constat J1 :** Problèmes de certificats clients identifiés - contournés en utilisant le bon certificat.

| Élément | Valeur |
|---------|--------|
| Format keystore | JKS ou PKCS12 |
| Chemin truststore | /etc/kafka/truststore.jks |
| Chemin keystore | /etc/kafka/keystore.jks |
| CA interne | À documenter |
| Clusters | NEMO (3 brokers), Applicatif (3 brokers) |
| Workers MM2 | 2-3 workers |

---

## 1. Inventaire des Certificats

### 1.1 Matrice des Certificats

| Composant | Serveur | Type | Chemin | Alias | Expiration | Statut |
|-----------|---------|------|--------|-------|------------|--------|
| Broker Source 1 | `${SRC_BROKER_1_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| Broker Source 2 | `${SRC_BROKER_2_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| Broker Source 3 | `${SRC_BROKER_3_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| Broker Cible 1 | `${TGT_BROKER_1_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| Broker Cible 2 | `${TGT_BROKER_2_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| Broker Cible 3 | `${TGT_BROKER_3_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${BROKER_ALIAS}` | - | ⬜ |
| MM2 Worker 1 | `${MM2_WORKER_1_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${MM2_ALIAS}` | - | ⬜ |
| MM2 Worker 2 | `${MM2_WORKER_2_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${MM2_ALIAS}` | - | ⬜ |
| MM2 Worker 3 | `${MM2_WORKER_3_HOST}` | Keystore | `${KEYSTORE_PATH}` | `${MM2_ALIAS}` | - | ⬜ |
| CA Root | Central | PEM | `${CA_ROOT_PATH}` | - | - | ⬜ |
| CA Intermédiaire | Central | PEM | `${CA_INTER_PATH}` | - | - | ⬜ |
| Truststore | Tous | JKS | `${TRUSTSTORE_PATH}` | - | - | ⬜ |

---

## 2. Script de Vérification Complète

### 2.1 Script Principal

```bash
#!/bin/bash
# check-certificates.sh
# Vérification complète des certificats de l'infrastructure

OUTPUT_DIR="cert-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

# Couleurs pour affichage
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Seuils en jours
CRITICAL_DAYS=7
WARNING_DAYS=30
NOTICE_DAYS=90

log_result() {
    local component=$1
    local server=$2
    local days_remaining=$3
    local expiry_date=$4

    if [ "$days_remaining" -lt $CRITICAL_DAYS ]; then
        status="CRITICAL"
        color=$RED
    elif [ "$days_remaining" -lt $WARNING_DAYS ]; then
        status="WARNING"
        color=$YELLOW
    elif [ "$days_remaining" -lt $NOTICE_DAYS ]; then
        status="NOTICE"
        color=$YELLOW
    else
        status="OK"
        color=$GREEN
    fi

    echo -e "${color}[$status]${NC} $component @ $server: ${days_remaining} jours restants (expire: $expiry_date)"
    echo "$component,$server,$days_remaining,$expiry_date,$status" >> $OUTPUT_DIR/results.csv
}

# Header CSV
echo "component,server,days_remaining,expiry_date,status" > $OUTPUT_DIR/results.csv

# === Vérification des brokers ===
echo "=== Vérification Brokers Source ==="
for broker in ${SRC_BROKER_1_HOST} ${SRC_BROKER_2_HOST} ${SRC_BROKER_3_HOST}; do
    echo "Checking $broker..."

    # Méthode 1: Via connexion SSL directe
    CERT_INFO=$(echo | openssl s_client -connect $broker:9093 -servername $broker 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)

    if [ -n "$CERT_INFO" ]; then
        EXPIRY_DATE=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_REMAINING=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        log_result "Broker-Source" "$broker" "$DAYS_REMAINING" "$EXPIRY_DATE"

        # Sauvegarder le certificat
        echo | openssl s_client -connect $broker:9093 -servername $broker 2>/dev/null | \
            openssl x509 > $OUTPUT_DIR/cert-$broker.pem 2>/dev/null
    else
        echo -e "${RED}[ERROR]${NC} Impossible de se connecter à $broker:9093"
        echo "Broker-Source,$broker,-1,ERROR,ERROR" >> $OUTPUT_DIR/results.csv
    fi
done

echo ""
echo "=== Vérification Brokers Cible ==="
for broker in ${TGT_BROKER_1_HOST} ${TGT_BROKER_2_HOST} ${TGT_BROKER_3_HOST}; do
    echo "Checking $broker..."

    CERT_INFO=$(echo | openssl s_client -connect $broker:9093 -servername $broker 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)

    if [ -n "$CERT_INFO" ]; then
        EXPIRY_DATE=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_REMAINING=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        log_result "Broker-Target" "$broker" "$DAYS_REMAINING" "$EXPIRY_DATE"
    else
        echo -e "${RED}[ERROR]${NC} Impossible de se connecter à $broker:9093"
        echo "Broker-Target,$broker,-1,ERROR,ERROR" >> $OUTPUT_DIR/results.csv
    fi
done

echo ""
echo "=== Vérification Keystores via SSH ==="
for server in ${SRC_BROKER_1_HOST} ${MM2_WORKER_1_HOST}; do
    echo "Checking keystore on $server..."

    KEYSTORE_INFO=$(ssh ${SSH_USER}@$server "keytool -list -v \
        -keystore ${KEYSTORE_PATH} \
        -storepass '${KEYSTORE_PASSWORD}' 2>/dev/null | grep -A2 'Valid from'")

    if [ -n "$KEYSTORE_INFO" ]; then
        EXPIRY_LINE=$(echo "$KEYSTORE_INFO" | grep "until:")
        EXPIRY_DATE=$(echo "$EXPIRY_LINE" | sed 's/.*until: //')

        # Parser la date
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
        if [ -n "$EXPIRY_EPOCH" ]; then
            NOW_EPOCH=$(date +%s)
            DAYS_REMAINING=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
            log_result "Keystore" "$server" "$DAYS_REMAINING" "$EXPIRY_DATE"
        fi
    fi
done

echo ""
echo "=== Résumé ==="
echo "Résultats sauvegardés dans $OUTPUT_DIR/"

# Compter les alertes
CRITICAL_COUNT=$(grep ",CRITICAL" $OUTPUT_DIR/results.csv | wc -l)
WARNING_COUNT=$(grep ",WARNING" $OUTPUT_DIR/results.csv | wc -l)
OK_COUNT=$(grep ",OK" $OUTPUT_DIR/results.csv | wc -l)

echo ""
echo "Statistiques:"
echo -e "  ${GREEN}OK:${NC} $OK_COUNT"
echo -e "  ${YELLOW}WARNING:${NC} $WARNING_COUNT"
echo -e "  ${RED}CRITICAL:${NC} $CRITICAL_COUNT"

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}ATTENTION: $CRITICAL_COUNT certificat(s) expire(nt) dans moins de $CRITICAL_DAYS jours!${NC}"
    exit 2
elif [ $WARNING_COUNT -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}ATTENTION: $WARNING_COUNT certificat(s) expire(nt) dans moins de $WARNING_DAYS jours.${NC}"
    exit 1
fi

exit 0
```

### 2.2 Script de Vérification Keystore Détaillée

```bash
#!/bin/bash
# check-keystore-detail.sh
# Usage: ./check-keystore-detail.sh <server> <keystore_path> <password>

SERVER=$1
KEYSTORE=$2
PASSWORD=$3

echo "=== Analyse détaillée du keystore sur $SERVER ==="

ssh ${SSH_USER}@$SERVER << EOF
echo "--- Informations générales ---"
keytool -list -keystore $KEYSTORE -storepass '$PASSWORD' 2>/dev/null

echo ""
echo "--- Détails des entrées ---"
keytool -list -v -keystore $KEYSTORE -storepass '$PASSWORD' 2>/dev/null | \
    grep -E "Alias name|Entry type|Owner|Issuer|Valid from|Serial number|Signature algorithm"

echo ""
echo "--- Vérification de la chaîne ---"
keytool -list -v -keystore $KEYSTORE -storepass '$PASSWORD' 2>/dev/null | \
    grep -E "Certificate\[|Owner:|Issuer:"

echo ""
echo "--- Algorithmes utilisés ---"
keytool -list -v -keystore $KEYSTORE -storepass '$PASSWORD' 2>/dev/null | \
    grep -E "Signature algorithm|Public Key Algorithm"
EOF
```

---

## 3. Vérifications Détaillées

### 3.1 Vérification de la Chaîne de Certification

```bash
# === Extraire et vérifier la chaîne complète ===
SERVER=${SRC_BROKER_1_HOST}
PORT=9093

echo "=== Extraction de la chaîne de certificats de $SERVER:$PORT ==="

# Extraire tous les certificats
openssl s_client -connect $SERVER:$PORT -showcerts 2>/dev/null < /dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' > /tmp/fullchain.pem

# Séparer les certificats individuels
csplit -f /tmp/cert- -b '%02d.pem' /tmp/fullchain.pem '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null
rm -f /tmp/cert-00.pem  # Fichier vide

# Analyser chaque certificat
for cert in /tmp/cert-*.pem; do
    if [ -s "$cert" ]; then
        echo ""
        echo "=== Certificat: $cert ==="
        openssl x509 -in $cert -noout -subject -issuer -dates
    fi
done

# Vérifier la chaîne
echo ""
echo "=== Vérification de la chaîne ==="
openssl verify -CAfile ${CA_ROOT_PATH} -untrusted ${CA_INTER_PATH} /tmp/cert-01.pem

# Nettoyage
rm -f /tmp/cert-*.pem /tmp/fullchain.pem
```

### 3.2 Vérification des Subject Alternative Names (SAN)

```bash
# === Vérifier les SAN des certificats ===
for server in ${SRC_BROKER_1_HOST} ${SRC_BROKER_2_HOST} ${SRC_BROKER_3_HOST}; do
    echo "=== SAN pour $server ==="
    echo | openssl s_client -connect $server:9093 2>/dev/null | \
        openssl x509 -noout -text | \
        grep -A1 "Subject Alternative Name" | tail -1

    # Vérifier que le hostname est dans les SAN
    SANS=$(echo | openssl s_client -connect $server:9093 2>/dev/null | \
        openssl x509 -noout -text | grep -A1 "Subject Alternative Name")

    if echo "$SANS" | grep -q "$server"; then
        echo "✅ Hostname $server présent dans les SAN"
    else
        echo "❌ Hostname $server ABSENT des SAN"
    fi
    echo ""
done
```

### 3.3 Vérification des Algorithmes de Signature

```bash
# === Vérifier les algorithmes utilisés ===
echo "=== Algorithmes de signature des certificats ==="

for server in ${SRC_BROKER_1_HOST} ${TGT_BROKER_1_HOST} ${MM2_WORKER_1_HOST}; do
    echo "--- $server ---"
    ALGO=$(echo | openssl s_client -connect $server:9093 2>/dev/null | \
        openssl x509 -noout -text | grep "Signature Algorithm" | head -1)
    echo "$ALGO"

    # Vérifier que l'algorithme est sécurisé
    if echo "$ALGO" | grep -qE "sha256|sha384|sha512"; then
        echo "✅ Algorithme sécurisé"
    elif echo "$ALGO" | grep -qE "sha1|md5"; then
        echo "❌ Algorithme déprécié/faible"
    fi
    echo ""
done
```

---

## 4. Validation de la Correspondance Clé/Certificat

### 4.1 Vérifier la Correspondance

```bash
#!/bin/bash
# verify-key-cert-match.sh
# Vérifie que la clé privée correspond au certificat

SERVER=$1

echo "=== Vérification correspondance clé/certificat sur $SERVER ==="

ssh ${SSH_USER}@$SERVER << 'EOF'
KEYSTORE="${KEYSTORE_PATH}"
PASSWORD="${KEYSTORE_PASSWORD}"
ALIAS="${BROKER_ALIAS}"

# Extraire le certificat
keytool -exportcert -keystore $KEYSTORE -storepass "$PASSWORD" -alias $ALIAS -rfc > /tmp/cert.pem 2>/dev/null

# Extraire la clé privée (nécessite conversion en PKCS12 puis extraction)
keytool -importkeystore -srckeystore $KEYSTORE -srcstorepass "$PASSWORD" \
    -destkeystore /tmp/keystore.p12 -deststoretype PKCS12 -deststorepass "$PASSWORD" -srcalias $ALIAS 2>/dev/null

openssl pkcs12 -in /tmp/keystore.p12 -nodes -nocerts -passin pass:"$PASSWORD" 2>/dev/null | \
    openssl rsa -out /tmp/key.pem 2>/dev/null

# Comparer les modulus
CERT_MOD=$(openssl x509 -in /tmp/cert.pem -noout -modulus | md5sum)
KEY_MOD=$(openssl rsa -in /tmp/key.pem -noout -modulus 2>/dev/null | md5sum)

echo "Modulus certificat: $CERT_MOD"
echo "Modulus clé:        $KEY_MOD"

if [ "$CERT_MOD" = "$KEY_MOD" ]; then
    echo "✅ Correspondance OK - La clé privée correspond au certificat"
else
    echo "❌ ERREUR - La clé privée NE correspond PAS au certificat"
fi

# Nettoyage
rm -f /tmp/cert.pem /tmp/key.pem /tmp/keystore.p12
EOF
```

---

## 5. Procédure de Renouvellement

### 5.1 Checklist de Renouvellement

```markdown
## Checklist Renouvellement Certificat

### Pré-renouvellement
- [ ] Identifier les certificats à renouveler (< 30 jours)
- [ ] Planifier la fenêtre de maintenance
- [ ] Préparer les nouveaux certificats
- [ ] Tester les nouveaux certificats en environnement de test
- [ ] Prévenir les équipes

### Renouvellement
- [ ] Sauvegarder les keystores actuels
- [ ] Importer les nouveaux certificats
- [ ] Redémarrer les services (rolling restart)
- [ ] Vérifier les connexions TLS
- [ ] Vérifier les logs d'erreur

### Post-renouvellement
- [ ] Valider la réplication MM2
- [ ] Mettre à jour l'inventaire des certificats
- [ ] Documenter le renouvellement
```

### 5.2 Commandes de Renouvellement

```bash
#!/bin/bash
# renew-certificate.sh
# Usage: ./renew-certificate.sh <server> <new_cert_path> <new_key_path>

SERVER=$1
NEW_CERT=$2
NEW_KEY=$3

echo "=== Renouvellement certificat sur $SERVER ==="

# 1. Sauvegarder le keystore actuel
echo "1. Sauvegarde du keystore actuel..."
ssh ${SSH_USER}@$SERVER "cp ${KEYSTORE_PATH} ${KEYSTORE_PATH}.backup.$(date +%Y%m%d)"

# 2. Créer un nouveau keystore PKCS12 avec le nouveau certificat
echo "2. Création du nouveau keystore..."
openssl pkcs12 -export \
    -in $NEW_CERT \
    -inkey $NEW_KEY \
    -out /tmp/new-keystore.p12 \
    -name ${BROKER_ALIAS} \
    -CAfile ${CA_CHAIN_PATH} \
    -caname root \
    -password pass:${KEYSTORE_PASSWORD}

# 3. Convertir en JKS si nécessaire
keytool -importkeystore \
    -srckeystore /tmp/new-keystore.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass ${KEYSTORE_PASSWORD} \
    -destkeystore /tmp/new-keystore.jks \
    -deststoretype JKS \
    -deststorepass ${KEYSTORE_PASSWORD}

# 4. Transférer et remplacer
echo "3. Transfert du nouveau keystore..."
scp /tmp/new-keystore.jks ${SSH_USER}@$SERVER:${KEYSTORE_PATH}.new
ssh ${SSH_USER}@$SERVER "mv ${KEYSTORE_PATH}.new ${KEYSTORE_PATH}"

# 5. Redémarrer le service
echo "4. Redémarrage du service..."
ssh ${SSH_USER}@$SERVER "sudo systemctl restart ${KAFKA_SERVICE}"

# 6. Vérification
echo "5. Vérification..."
sleep 10
if openssl s_client -connect $SERVER:9093 2>/dev/null | openssl x509 -noout -dates; then
    echo "✅ Renouvellement réussi"
else
    echo "❌ Erreur - rollback recommandé"
fi

# Nettoyage
rm -f /tmp/new-keystore.*
```

---

## 6. Monitoring des Certificats

### 6.1 Métriques Prometheus (via blackbox_exporter)

```yaml
# prometheus/blackbox.yml
modules:
  tls_connect:
    prober: tcp
    timeout: 5s
    tcp:
      tls: true
      tls_config:
        insecure_skip_verify: false

# prometheus/prometheus.yml
scrape_configs:
  - job_name: 'ssl_expiry'
    metrics_path: /probe
    params:
      module: [tls_connect]
    static_configs:
      - targets:
        - ${SRC_BROKER_1_HOST}:9093
        - ${SRC_BROKER_2_HOST}:9093
        - ${SRC_BROKER_3_HOST}:9093
        - ${TGT_BROKER_1_HOST}:9093
        - ${TGT_BROKER_2_HOST}:9093
        - ${TGT_BROKER_3_HOST}:9093
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox_exporter:9115
```

### 6.2 Alertes Prometheus

```yaml
# alerting-rules-ssl.yml
groups:
  - name: ssl_certificates
    rules:
      - alert: SSLCertExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSL Certificate expiring soon on {{ $labels.instance }}"
          description: "SSL certificate expires in {{ $value | humanizeDuration }}"

      - alert: SSLCertExpiryCritical
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "SSL Certificate expiring very soon on {{ $labels.instance }}"
          description: "SSL certificate expires in {{ $value | humanizeDuration }}"

      - alert: SSLCertExpired
        expr: probe_ssl_earliest_cert_expiry - time() < 0
        labels:
          severity: critical
        annotations:
          summary: "SSL Certificate EXPIRED on {{ $labels.instance }}"
```

### 6.3 Dashboard Grafana - Expiration Certificats

```json
{
  "panels": [
    {
      "title": "Days Until Certificate Expiry",
      "type": "stat",
      "targets": [
        {
          "expr": "(probe_ssl_earliest_cert_expiry - time()) / 86400",
          "legendFormat": "{{ instance }}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "value": 0, "color": "red" },
              { "value": 7, "color": "orange" },
              { "value": 30, "color": "yellow" },
              { "value": 90, "color": "green" }
            ]
          },
          "unit": "d"
        }
      }
    }
  ]
}
```

---

## 7. Tableau de Suivi des Certificats

### 7.1 Template de Suivi

| Certificat | Serveur | Date Émission | Date Expiration | Jours Restants | Prochaine Action | Responsable |
|------------|---------|---------------|-----------------|----------------|------------------|-------------|
| Broker Src 1 | - | - | - | - | - | - |
| Broker Src 2 | - | - | - | - | - | - |
| Broker Src 3 | - | - | - | - | - | - |
| Broker Tgt 1 | - | - | - | - | - | - |
| Broker Tgt 2 | - | - | - | - | - | - |
| Broker Tgt 3 | - | - | - | - | - | - |
| MM2 Worker 1 | - | - | - | - | - | - |
| MM2 Worker 2 | - | - | - | - | - | - |
| MM2 Worker 3 | - | - | - | - | - | - |
| CA Root | - | - | - | - | - | - |
| CA Inter | - | - | - | - | - | - |

### 7.2 Calendrier de Renouvellement

| Mois | Certificats à Renouveler | Action Planifiée |
|------|-------------------------|------------------|
| - | - | - |

---

## 8. Critères d'Acceptation

| Critère | Obligatoire | Résultat |
|---------|-------------|----------|
| Tous certificats valides > 30 jours | OUI | ⬜ |
| Chaîne de certification complète | OUI | ⬜ |
| SAN incluent les hostnames | OUI | ⬜ |
| Algorithmes SHA-256+ | OUI | ⬜ |
| Correspondance clé/certificat | OUI | ⬜ |
| Monitoring en place | OUI | ⬜ |
| Procédure renouvellement documentée | OUI | ⬜ |

---

## 9. Actions Issues J1

| Priorité | Action | Responsable | Statut |
|----------|--------|-------------|--------|
| P1 | Vérifier validité tous certificats | - | [ ] |
| P2 | Mettre en place monitoring expiration | - | [ ] |
| P2 | Documenter procédure renouvellement | - | [ ] |
| P2 | Identifier problème certificats clients J1 | - | [x] Contourné |

---

## Artifacts Produits

- [ ] Inventaire certificats complété
- [ ] Rapport d'audit (`cert-audit-*/results.csv`)
- [ ] Certificats extraits pour archivage
- [ ] Alertes monitoring configurées
- [ ] Procédure de renouvellement testée

---

**Client** : Transactis
**Constat J1** : Problème certificats clients (contourné)
**Version** : 2.0

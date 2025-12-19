# Tests TLS et SASL - Sécurité MirrorMaker 2 Transactis

## Objectif

Valider la configuration et le bon fonctionnement des mécanismes de sécurité TLS et SASL sur l'infrastructure Kafka NEMO, Applicatif et MirrorMaker 2.

---

## Pré-requis

- [x] Accès aux fichiers de configuration sécurité
- [x] Configuration SASL_SSL en place (SCRAM-SHA-512)
- [x] Certificats et keystores accessibles
- [x] Accès SSH aux serveurs validé (cf. `01-prerequis/inventaire-acces.md`)

---

## Contexte Transactis

| Élément | Configuration |
|---------|---------------|
| Protocole | SASL_SSL |
| Mécanisme SASL | SCRAM-SHA-512 |
| Port sécurisé Kafka | 9093 |
| Version TLS cible | TLS 1.2 / 1.3 |
| Clusters | NEMO (Source), Applicatif (Cible) |

**Constat J1 :** Problèmes de certificats clients identifiés - contournés en utilisant le bon certificat.
**Constat J1 :** ACLs non configurées - tous les accès sont ouverts (risque sécurité P0).

---

## 1. Architecture de Sécurité

### 1.1 Configuration Cible

| Composant | Protocole | Port | Mécanisme |
|-----------|-----------|------|-----------|
| Kafka Brokers NEMO | SASL_SSL | 9093 | TLS 1.2+ / SCRAM-SHA-512 |
| Kafka Brokers Applicatif | SASL_SSL | 9093 | TLS 1.2+ / SCRAM-SHA-512 |
| ZooKeeper | - | 2181 | Digest (optionnel) |
| Connect REST (MM2) | HTTP | 8083 | Non sécurisé actuellement |
| JMX Exporter Brokers | HTTP | 7070 | Non authentifié |
| JMX Exporter Connect | HTTP | 7072 | Non authentifié |

### 1.2 Flux de Communication Sécurisés

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLUSTER SOURCE                              │
│  ┌─────────────┐                      ┌─────────────┐           │
│  │   Broker    │◄───── SASL_SSL ─────►│   Broker    │           │
│  │  (9093)     │       (inter-broker) │  (9093)     │           │
│  └──────┬──────┘                      └──────┬──────┘           │
│         │                                     │                  │
│         └──────────────┬──────────────────────┘                  │
│                        │                                         │
│                   SASL_SSL                                       │
│                  (MM2 consumer)                                  │
└────────────────────────┼────────────────────────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   MirrorMaker 2     │
              │   (SASL_SSL)        │
              │   User: ${MM2_USER} │
              └─────────┬───────────┘
                        │
                   SASL_SSL
                  (MM2 producer)
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CLUSTER CIBLE                               │
│  ┌─────────────┐                      ┌─────────────┐           │
│  │   Broker    │◄───── SASL_SSL ─────►│   Broker    │           │
│  │  (9093)     │       (inter-broker) │  (9093)     │           │
│  └─────────────┘                      └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Tests TLS

### 2.1 Test SEC-TLS-01 : Validation des Certificats

**Objectif :** Vérifier que les certificats sont valides, non expirés et correctement configurés.

#### Étapes et Commandes

```bash
# === Test 1: Vérifier la validité du certificat broker ===
echo "=== Certificat Broker Source ==="
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -servername ${SRC_BROKER_1_HOST} 2>/dev/null | \
    openssl x509 -noout -dates -subject -issuer

# Résultat attendu:
# notBefore=...
# notAfter=... (date future)
# subject=CN=...
# issuer=CN=...

# === Test 2: Vérifier la chaîne de certification complète ===
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -showcerts 2>/dev/null | \
    grep -E "Certificate chain|s:|i:"

# === Test 3: Vérifier le CN/SAN du certificat ===
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 2>/dev/null | \
    openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# === Test 4: Tester la version TLS ===
# TLS 1.2
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1_2 2>/dev/null | head -5

# TLS 1.3 (si supporté)
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1_3 2>/dev/null | head -5

# Vérifier que TLS 1.0/1.1 sont désactivés (doit échouer)
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1 2>&1 | grep -E "error|failed"
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1_1 2>&1 | grep -E "error|failed"
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| Certificat valide | notAfter > aujourd'hui + 30 jours | Expiré ou < 30 jours |
| Chaîne complète | CA intermédiaire + Root présents | Chaîne incomplète |
| CN/SAN correct | Correspond au hostname | Mismatch |
| TLS 1.2+ | Connexion réussie | Échec |
| TLS 1.0/1.1 | Connexion refusée | Connexion acceptée |

### 2.2 Test SEC-TLS-02 : Validation Keystore/Truststore

**Objectif :** Vérifier l'intégrité et la configuration des keystores et truststores.

#### Étapes et Commandes

```bash
# === Vérification Keystore ===
echo "=== Contenu Keystore ==="
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "keytool -list -v \
    -keystore ${KEYSTORE_PATH} \
    -storepass '${KEYSTORE_PASSWORD}'" | grep -E "Alias|Entry|Valid|Owner"

# === Vérification Truststore ===
echo "=== Contenu Truststore ==="
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "keytool -list -v \
    -keystore ${TRUSTSTORE_PATH} \
    -storepass '${TRUSTSTORE_PASSWORD}'" | grep -E "Alias|Entry|Valid|Owner"

# === Vérifier que le keystore contient une clé privée ===
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "keytool -list \
    -keystore ${KEYSTORE_PATH} \
    -storepass '${KEYSTORE_PASSWORD}'" | grep "PrivateKeyEntry"

# === Vérifier la correspondance certificat/clé ===
# Extraire le certificat du keystore
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "keytool -exportcert \
    -keystore ${KEYSTORE_PATH} \
    -storepass '${KEYSTORE_PASSWORD}' \
    -alias ${KEYSTORE_ALIAS} \
    -rfc" > /tmp/broker-cert.pem

# Vérifier
openssl x509 -in /tmp/broker-cert.pem -noout -modulus | md5sum
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| Keystore accessible | Lecture OK | Erreur password/fichier |
| Truststore accessible | Lecture OK | Erreur password/fichier |
| Clé privée présente | PrivateKeyEntry trouvé | Absent |
| Certificats valides | Dates valides | Expirés |

### 2.3 Test SEC-TLS-03 : Test de Connexion TLS End-to-End

**Objectif :** Valider qu'un client peut se connecter en TLS au cluster.

#### Étapes et Commandes

```bash
# === Test connexion avec kafka-broker-api-versions ===
# Créer le fichier de configuration client SSL
cat > /tmp/ssl-client.properties << EOF
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SSL
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF

# Tester la connexion
$KAFKA_HOME/bin/kafka-broker-api-versions.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/ssl-client.properties

# === Test avec openssl (debug) ===
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 \
    -CAfile ${CA_CERT_PATH} \
    -cert ${CLIENT_CERT_PATH} \
    -key ${CLIENT_KEY_PATH} \
    -state -debug 2>&1 | head -50

# === Capture du handshake TLS ===
# (Nécessite tcpdump et wireshark pour analyse)
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "sudo timeout 10 tcpdump -i any port 9093 -w /tmp/tls-capture.pcap" &
sleep 2
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/ssl-client.properties \
    --list
sleep 10
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| API versions | Liste des versions retournée | Erreur connexion |
| Handshake TLS | Completed | SSL handshake failure |
| Cipher suite | Suite forte (AES-256, etc.) | Suite faible |

---

## 3. Tests SASL

### 3.1 Test SEC-SASL-01 : Authentification SCRAM

**Objectif :** Valider l'authentification SASL/SCRAM.

#### Étapes et Commandes

```bash
# === Créer la configuration client SASL_SSL ===
cat > /tmp/sasl-client.properties << EOF
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${PERF_TEST_USER}" \
    password="${PERF_TEST_PASSWORD}";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF

# === Test 1: Authentification valide ===
echo "=== Test authentification valide ==="
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/sasl-client.properties \
    --list

# Résultat attendu: liste des topics sans erreur

# === Test 2: Authentification avec mauvais password ===
echo "=== Test authentification invalide (mauvais password) ==="
cat > /tmp/sasl-bad-password.properties << EOF
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${PERF_TEST_USER}" \
    password="wrongpassword123";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF

$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/sasl-bad-password.properties \
    --list 2>&1 | grep -E "Authentication failed|SASL"

# Résultat attendu: erreur d'authentification

# === Test 3: Authentification avec utilisateur inexistant ===
echo "=== Test authentification invalide (utilisateur inexistant) ==="
cat > /tmp/sasl-bad-user.properties << EOF
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="nonexistentuser" \
    password="somepassword";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF

$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/sasl-bad-user.properties \
    --list 2>&1 | grep -E "Authentication failed|SASL"

# Résultat attendu: erreur d'authentification

# === Nettoyage ===
rm -f /tmp/sasl-*.properties
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| Auth valide | Connexion réussie | Échec |
| Mauvais password | Authentification refusée | Connexion acceptée |
| User inexistant | Authentification refusée | Connexion acceptée |
| Message d'erreur | Explicite et sécurisé | Fuite d'information |

### 3.2 Test SEC-SASL-02 : Validation des ACLs

**Objectif :** Vérifier que les ACLs sont correctement appliquées.

#### Étapes et Commandes

```bash
# === Lister les ACLs existantes ===
echo "=== ACLs Cluster Source ==="
$KAFKA_HOME/bin/kafka-acls.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${ADMIN_PROPERTIES_PATH} \
    --list

# === Test 1: Utilisateur MM2 peut lire les topics ===
echo "=== Test lecture MM2 ==="
cat > /tmp/mm2-client.properties << EOF
bootstrap.servers=${SRC_BOOTSTRAP_SERVERS}
security.protocol=SASL_SSL
sasl.mechanism=${SASL_MECHANISM}
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="${MM2_USER_SOURCE}" \
    password="${MM2_USER_SOURCE_PASSWORD}";
ssl.truststore.location=${TRUSTSTORE_PATH}
ssl.truststore.password=${TRUSTSTORE_PASSWORD}
group.id=test-acl-group
EOF

# Tenter de consommer (doit réussir si ACL READ accordée)
timeout 10 $KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --consumer.config /tmp/mm2-client.properties \
    --topic test-mm2-perf \
    --max-messages 1 2>&1

# === Test 2: Utilisateur restreint ne peut pas créer de topic ===
echo "=== Test création topic (doit échouer si pas d'ACL CREATE) ==="
$KAFKA_HOME/bin/kafka-topics.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config /tmp/mm2-client.properties \
    --create \
    --topic test-unauthorized-topic \
    --partitions 1 \
    --replication-factor 1 2>&1 | grep -E "Authorization|denied|not authorized"

# === Test 3: Utilisateur perf-test peut écrire sur test-* ===
echo "=== Test écriture perf-test ==="
echo "test-message" | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config /tmp/sasl-client.properties \
    --topic test-mm2-perf 2>&1

# === Test 4: Utilisateur ne peut pas écrire sur topic non autorisé ===
echo "=== Test écriture non autorisée ==="
echo "test-message" | $KAFKA_HOME/bin/kafka-console-producer.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --producer.config /tmp/mm2-client.properties \
    --topic __consumer_offsets 2>&1 | grep -E "Authorization|denied|not authorized"
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| MM2 lecture | Autorisé | Refusé |
| MM2 écriture cible | Autorisé | Refusé |
| Création topic non autorisé | Refusé | Autorisé |
| Écriture topic système | Refusé | Autorisé |

### 3.3 Test SEC-SASL-03 : Authentification MM2 Inter-Cluster

**Objectif :** Valider que MM2 s'authentifie correctement sur les deux clusters.

#### Étapes et Commandes

```bash
# === Vérifier la configuration MM2 ===
echo "=== Configuration connecteur MirrorSource ==="
curl -s http://${MM2_WORKER_1_HOST}:${CONNECT_REST_PORT}/connectors/${MM2_SOURCE_CONNECTOR_NAME}/config | jq .

# === Vérifier les connexions actives du consumer MM2 ===
$KAFKA_HOME/bin/kafka-consumer-groups.sh \
    --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
    --command-config ${CLIENT_PROPERTIES_PATH} \
    --describe \
    --all-groups | grep -i mirror

# === Vérifier les logs d'authentification MM2 ===
ssh ${SSH_USER}@${MM2_WORKER_1_HOST} "sudo grep -E 'SASL|Authentication|authenticated' /var/log/kafka-connect/connect.log | tail -20"

# === Test de connectivité MM2 vers source ===
ssh ${SSH_USER}@${MM2_WORKER_1_HOST} "
    echo 'Test connexion MM2 -> Source'
    $KAFKA_HOME/bin/kafka-broker-api-versions.sh \
        --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} \
        --command-config ${MM2_SOURCE_CLIENT_CONFIG}
"

# === Test de connectivité MM2 vers cible ===
ssh ${SSH_USER}@${MM2_WORKER_1_HOST} "
    echo 'Test connexion MM2 -> Cible'
    $KAFKA_HOME/bin/kafka-broker-api-versions.sh \
        --bootstrap-server ${TGT_BOOTSTRAP_SERVERS} \
        --command-config ${MM2_TARGET_CLIENT_CONFIG}
"
```

#### Critères de Succès

| Vérification | Critère OK | Critère KO |
|--------------|------------|------------|
| Config MM2 correcte | Credentials présents | Credentials manquants |
| Consumer group MM2 actif | Groupe visible | Groupe absent |
| Logs authentification | "authenticated" | "failed" |
| Connexion source | OK | Erreur |
| Connexion cible | OK | Erreur |

---

## 4. Tests de Sécurité Avancés

### 4.1 Test SEC-ADV-01 : Test de Cipher Suites

**Objectif :** Vérifier que seuls les cipher suites sécurisés sont acceptés.

```bash
# === Scanner les cipher suites supportés ===
nmap --script ssl-enum-ciphers -p 9093 ${SRC_BROKER_1_HOST}

# === OU avec testssl.sh ===
# git clone https://github.com/drwetter/testssl.sh.git
./testssl.sh --cipher-per-proto ${SRC_BROKER_1_HOST}:9093

# === Vérifier qu'un cipher faible est refusé ===
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -cipher DES-CBC3-SHA 2>&1 | grep -E "error|Cipher"
```

#### Cipher Suites Recommandés

| Catégorie | Cipher Suite | Accepté |
|-----------|--------------|---------|
| ✅ Recommandé | TLS_AES_256_GCM_SHA384 | Oui |
| ✅ Recommandé | TLS_CHACHA20_POLY1305_SHA256 | Oui |
| ✅ Acceptable | TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 | Oui |
| ❌ Déprécié | TLS_RSA_WITH_3DES_EDE_CBC_SHA | Non |
| ❌ Faible | TLS_RSA_WITH_RC4_128_SHA | Non |

### 4.2 Test SEC-ADV-02 : Test de Downgrade Attack

**Objectif :** Vérifier la résistance aux attaques de downgrade TLS.

```bash
# === Tenter une connexion avec protocole ancien ===
# TLS 1.0 (doit échouer)
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1 2>&1

# TLS 1.1 (doit échouer)
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -tls1_1 2>&1

# SSLv3 (doit échouer)
openssl s_client -connect ${SRC_BROKER_1_HOST}:9093 -ssl3 2>&1
```

### 4.3 Test SEC-ADV-03 : Test d'Injection de Credentials

**Objectif :** Vérifier que les credentials ne sont pas exposés dans les logs.

```bash
# === Vérifier que les passwords ne sont pas dans les logs ===
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "sudo grep -r '${PERF_TEST_PASSWORD}' /var/log/kafka/ 2>/dev/null | wc -l"

ssh ${SSH_USER}@${MM2_WORKER_1_HOST} "sudo grep -r '${MM2_USER_SOURCE_PASSWORD}' /var/log/kafka-connect/ 2>/dev/null | wc -l"

# Résultat attendu: 0

# === Vérifier que les passwords ne sont pas dans les fichiers de config accessibles ===
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "find /opt/kafka -name '*.properties' -exec grep -l password {} \; 2>/dev/null"

# Vérifier les permissions des fichiers sensibles
ssh ${SSH_USER}@${SRC_BROKER_1_HOST} "ls -la ${JAAS_CONFIG_PATH}"
# Attendu: permissions restrictives (600 ou 640)
```

---

## 5. Tableau de Résultats

### 5.1 Résultats Tests TLS

| Test | Description | Résultat | Observations |
|------|-------------|----------|--------------|
| SEC-TLS-01 | Validation certificats | ⬜ | - |
| SEC-TLS-02 | Keystore/Truststore | ⬜ | - |
| SEC-TLS-03 | Connexion E2E | ⬜ | - |

### 5.2 Résultats Tests SASL

| Test | Description | Résultat | Observations |
|------|-------------|----------|--------------|
| SEC-SASL-01 | Authentification SCRAM | ⬜ | - |
| SEC-SASL-02 | Validation ACLs | ⬜ | - |
| SEC-SASL-03 | Auth MM2 inter-cluster | ⬜ | - |

### 5.3 Résultats Tests Avancés

| Test | Description | Résultat | Observations |
|------|-------------|----------|--------------|
| SEC-ADV-01 | Cipher suites | ⬜ | - |
| SEC-ADV-02 | Downgrade attack | ⬜ | - |
| SEC-ADV-03 | Credentials exposure | ⬜ | - |

**Légende:** ✅ Pass | ⚠️ Warning | ❌ Fail | ⬜ Non testé

---

## 6. Critères d'Acceptation Sécurité

| Critère | Obligatoire | Résultat |
|---------|-------------|----------|
| TLS 1.2+ uniquement | OUI | ⬜ |
| Certificats valides > 30 jours | OUI | ⬜ |
| SASL authentification fonctionnelle | OUI | ⬜ |
| ACLs appliquées | OUI | ⬜ |
| Pas de credentials dans les logs | OUI | ⬜ |
| Cipher suites sécurisés | OUI | ⬜ |
| Fichiers sensibles protégés | OUI | ⬜ |

---

## 7. Actions Requises (Issues J1/J2)

| Priorité | Action | Responsable | Statut |
|----------|--------|-------------|--------|
| **P0** | Configurer ACLs sur NEMO et Applicatif | - | [ ] |
| P1 | Vérifier expiration certificats | - | [ ] |
| P1 | Désactiver TLS 1.0/1.1 si actif | - | [ ] |
| P2 | Documenter procédure rotation credentials | - | [ ] |
| P2 | Sécuriser Connect REST API (HTTPS) | - | [ ] |

---

## Artifacts Produits

- [ ] Rapport de scan TLS
- [ ] Liste des ACLs à créer
- [ ] Captures réseau (si applicable)
- [ ] Checklist de sécurité complétée

---

**Client** : Transactis
**Protocole** : SASL_SSL (SCRAM-SHA-512)
**Version** : 2.0

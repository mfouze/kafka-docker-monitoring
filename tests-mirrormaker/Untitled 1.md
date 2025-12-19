Tu es un consultant senior Kafka / Data Platform (SRE / Performance / Observabilité) en contexte production.

Objectif :
Produire un **rapport journalier technique – Jour 4 (jeudi 18/12/2025)**, structuré, factuel et exploitable par un client (équipes plateforme, SRE, architecture).
Le rapport doit couvrir :
- tests de performance avec **réplication MM2 en continu**,
- analyse de latence (broker, ZooKeeper) et throughput,
- corrections des dashboards Grafana/MM2,
- évolution du plan de tests (structure en fichiers .md),
- ajout de sécurité (Basic Auth / HTTPS) sur Schema Registry et Kafka Connect.

Contraintes STRICTES :
- Aucune invention ni extrapolation.
- Toute conclusion doit être appuyée par des logs, métriques ou observations mentionnées dans les notes.
- Si une information est manquante (ex : ressources VM, nb partitions, configs exactes du producer, configs MM2), l’indiquer explicitement.
- Ne pas sur-interpréter : distinguer clairement “observé” vs “hypothèse à valider”.
- Pas d’emojis, pas de ton marketing.

Livrable attendu :
Un rapport Markdown structuré comprenant :

1) **Résumé exécutif (5–10 lignes)**
   - Ce qui a été réalisé aujourd’hui
   - Résultats majeurs observés (latence / débit)
   - Risques / points bloquants éventuels
   - Priorités du Jour 5

2) **Matin – Tests perf avec réplication continue**
   - Description du tir de perf (paramètres exacts) :
     - throughput = -1
     - 1 800 000 messages
     - taille message = 512000 bytes (si c’est bien l’unité utilisée, sinon le signaler)
     - réplication en continu active
   - Observations :
     - baisse de la latence broker suite au tuning
     - latence ZooKeeper entre 3 et 14 ms
     - mention spécifique : latence 14 ms observée sur “datacenter north”
   - Impacts potentiels (sans spéculation) et points à valider

3) **Dashboards / Monitoring**
   - Réparation / correction des dashboards de monitoring MM2/Connect
   - Organisation des dashboards “par cluster” (source / target) si applicable
   - Indiquer ce qui manquait, ce qui a été corrigé, et ce qui reste à faire

4) **Après-midi – Formalisation du plan de tests**
   - Reprendre la table des étapes (0 à 10) fournie
   - Expliquer l’objectif de chaque étape en 1–2 phrases
   - Préciser les durées estimées (telles que fournies)
   - Mentionner comment ces fichiers seront utilisés (ordre d’exécution, critères de passage, artefacts attendus)

5) **Exécution des tests de performance – Résultats et lecture**
   - Structurer par scénarios avec un tableau :
     - Scénario (nom)
     - Commande
     - record-size
     - num-records
     - throughput cible
     - throughput obtenu
     - latence moyenne
     - max latency
     - percentiles (P50/P95/P99/P99.9 si présents)
     - remarques
   - Scénarios à inclure :
     A) Test avec record-size=51200, num-records=500000, throughput=1000
        - Résumé final : 500000 records, ~622.26 rec/s, ~30.38 MB/s, ~1050.68 ms avg, P50/P95/P99/P99.9
     B) Relance du test nominal (record-size=1024, num-records=1800000, throughput=1000, --print-metrics)
        - Résumé final : ~999.985 rec/s, ~22.21 ms avg, percentiles
        - Inclure un extrait synthétique des métriques producer pertinentes (sans lister tout)
     C) Test avec tuning producer (linger.ms=50, compression=lz4, batch.size=65536, buffer.memory=67108864)
        - Résultats : 18000 records, avg latency ~74.29 ms + percentiles
        - Expliquer factuellement pourquoi le comportement change (batching / compression / linger)
     D) Test “acks=1, linger=0, compression=lz4”
        - Résultats : 18000 records, avg latency ~13.76 ms + percentiles
     E) Benchmark record-size=10240, throughput=10000, acks=1, compression=lz4, linger=5, batch.size=32768
        - Inclure l’événement WARN LEADER_NOT_AVAILABLE et l’interprétation factuelle (événement de metadata/leader)
        - Résumé final : 1 800 000 records, ~6484 rec/s, ~63.32 MB/s, latence ~459.97 ms, percentiles

6) **Analyse factuelle et enseignements (sans sur-interprétation)**
   - Comparaison capping vs non-capping (si applicable)
   - Comparaison taille message (1KB vs 10KB vs 50KB)
   - Impact des paramètres producteurs (linger, batch.size, compression, acks) sur :
     - latence
     - throughput
     - percentiles
   - Corrélation avec métriques observées (CPU brokers, ZK latency) si disponible, sinon le signaler

7) **Sécurité mise en place**
   - Mise en place Basic Auth sur Schema Registry
   - Mise en place Basic Auth sur Kafka Connect MM2
   - Exposition HTTPS du REST service Kafka Connect
   - Décrire ce qui a été fait + ce qui reste à sécuriser (sans ajouter de composants non mentionnés)

8) **Risques / problèmes / points d’attention**
   - Eventuels problèmes réseau / datacenter
   - WARN LEADER_NOT_AVAILABLE (à investiguer)
   - Tout autre point relevé dans les notes

9) **Prochaines étapes (Jour 5)**
   - Proposer une liste courte et priorisée :
     - Finaliser exécution des étapes du plan de tests
     - Tests réplication bout-en-bout sous charge
     - Endurance 24h
     - Monitoring/alerting (si dans le scope)
     - Stabilisation sécurité

10) **Diagrammes Mermaid (obligatoire)**
   - Diagramme de séquence : Producer perf test → Kafka (source) → MM2 (Connect) → Kafka (target) + Prometheus/Grafana
   - Diagramme d’architecture : composants et flux (source/target, connect, schema registry, monitoring)
   - Diagramme “plan de test” : enchaînement des étapes 0 → 10

Format attendu :
- word
- Tableaux de synthèse
- Diagrammes Mermaid valides
- Sections clairement séparées : Observé / À valider / Actions

Données d’entrée (notes brutes – Jour 4) :
Notes de travail : jeudi 18/12/2025

Matinee :

-       Lancement  d’un tir de perf avec replication en continue

o   Througput -1

o   1 800 000

o   512000 by de message

-       On observer que la latence a baissé sur les envois sur le broker avec le tuning effectué

o   On constate aussi par ailleurs une latence zookeeper de entre 3 et 14 ms

o   Cette latence de 14ms est remarquee  sur des dacenteer north

Reparation des dashboards de monitring mm2 connect

Apres midi :

Lance du test 1 :

[root@3c67cc921beb appuser]# kafka-producer-perf-test  --topic "test-prometheus.generated-data-1800.json"   --num-records 500000   --record-size 51200   --throughput 1000  --producer.config bomberder.properties

Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/pki/tls/certs/kafka-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=jks

1878 records sent, 375.5 records/sec (18.34 MB/sec), 1260.0 ms avg latency, 4256.0 ms max latency.

3058 records sent, 611.2 records/sec (29.85 MB/sec), 1110.3 ms avg latency, 4277.0 ms max latency.

3095 records sent, 619.0 records/sec (30.22 MB/sec), 1058.6 ms avg latency, 1216.0 ms max latency.

3069 records sent, 613.7 records/sec (29.96 MB/sec), 1065.1 ms avg latency, 1253.0 ms max latency.

3088 records sent, 617.2 records/sec (30.14 MB/sec), 1064.9 ms avg latency, 1256.0 ms max latency.

3095 records sent, 619.0 records/sec (30.22 MB/sec), 1057.5 ms avg latency, 1202.0 ms max latency.

2952 records sent, 590.3 records/sec (28.82 MB/sec), 1108.7 ms avg latency, 1368.0 ms max latency.

3137 records sent, 627.4 records/sec (30.63 MB/sec), 1047.2 ms avg latency, 1215.0 ms max latency.

3133 records sent, 626.6 records/sec (30.60 MB/sec), 1044.2 ms avg latency, 1178.0 ms max latency.

....

3157 records sent, 631.3 records/sec (30.82 MB/sec), 1035.6 ms avg latency, 1182.0 ms max latency.

3183 records sent, 636.5 records/sec (31.08 MB/sec), 1029.8 ms avg latency, 1171.0 ms max latency.

3167 records sent, 633.3 records/sec (30.92 MB/sec), 1033.9 ms avg latency, 1214.0 ms max latency.

3118 records sent, 623.5 records/sec (30.44 MB/sec), 1037.4 ms avg latency, 1235.0 ms max latency.

3130 records sent, 625.9 records/sec (30.56 MB/sec), 1060.7 ms avg latency, 1263.0 ms max latency.

3187 records sent, 637.4 records/sec (31.12 MB/sec), 1026.2 ms avg latency, 1158.0 ms max latency.

3161 records sent, 631.9 records/sec (30.86 MB/sec), 1034.5 ms avg latency, 1185.0 ms max latency.

3190 records sent, 638.0 records/sec (31.15 MB/sec), 1028.4 ms avg latency, 1170.0 ms max latency.

3176 records sent, 634.9 records/sec (31.00 MB/sec), 1030.8 ms avg latency, 1178.0 ms max latency.

3156 records sent, 630.9 records/sec (30.81 MB/sec), 1039.0 ms avg latency, 1192.0 ms max latency.

3148 records sent, 629.6 records/sec (30.74 MB/sec), 1038.9 ms avg latency, 1215.0 ms max latency.

3171 records sent, 634.2 records/sec (30.97 MB/sec), 1034.6 ms avg latency, 1176.0 ms max latency.

3171 records sent, 634.2 records/sec (30.97 MB/sec), 1032.1 ms avg latency, 1172.0 ms max latency.

3176 records sent, 635.2 records/sec (31.02 MB/sec), 1030.8 ms avg latency, 1165.0 ms max latency.

500000 records sent, 622.255077 records/sec (30.38 MB/sec), 1050.68 ms avg latency, 4277.00 ms max latency, 1039 ms 50th, 1173 ms 95th, 1235 ms 99th, 1478 ms 99.9th.

-       Relance du premier test de perf avec le parametrage initial

[root@3c67cc921beb appuser]# kafka-producer-perf-test --topic "tire2-nominal-2.json"  --num-records 1800000  --record-size 1024  --throughput 1000  --producer.config bomberder.properties --print-metrics

....

1800000 records sent, 999.985000 records/sec (0.98 MB/sec), 22.21 ms avg latency, 701.00 ms max latency, 23 ms 50th, 31 ms 95th, 35 ms 99th, 63 ms 99.9th.

Metric Name                                                                                                                     Value

app-info:commit-id:{client-id=perf-producer-client}                                                                           : fdd7d97c55329e51485991b5fccc9bb91e83cf76

app-info:start-time-ms:{client-id=perf-producer-client}                                                                       : 1766064165399

app-info:version:{client-id=perf-producer-client}                                                                             : 7.7.7-ccs

kafka-metrics-count:count:{client-id=perf-producer-client}                                                                    : 149.000

producer-metrics:batch-size-avg:{client-id=perf-producer-client}                                                              : 3141.749

producer-metrics:batch-size-max:{client-id=perf-producer-client}                                                              : 15556.000

producer-metrics:batch-split-rate:{client-id=perf-producer-client}                                                            : 0.000

producer-metrics:batch-split-total:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:buffer-available-bytes:{client-id=perf-producer-client}                                                      : 33554432.000

producer-metrics:buffer-exhausted-rate:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:buffer-exhausted-total:{client-id=perf-producer-client}                                                      : 0.000

producer-metrics:buffer-total-bytes:{client-id=perf-producer-client}                                                          : 33554432.000

producer-metrics:bufferpool-wait-ratio:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:bufferpool-wait-time-ns-total:{client-id=perf-producer-client}                                               : 0.000

producer-metrics:bufferpool-wait-time-total:{client-id=perf-producer-client}                                                  : 0.000

producer-metrics:compression-rate-avg:{client-id=perf-producer-client}                                                        : 1.000

producer-metrics:connection-close-rate:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:connection-close-total:{client-id=perf-producer-client}                                                      : 3.000

producer-metrics:connection-count:{client-id=perf-producer-client}                                                            : 3.000

producer-metrics:connection-creation-rate:{client-id=perf-producer-client}                                                    : 0.000

producer-metrics:connection-creation-total:{client-id=perf-producer-client}                                                   : 6.000

producer-metrics:connections:{client-id=perf-producer-client, cipher=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384, protocol=TLSv1.2} : 3

producer-metrics:failed-authentication-rate:{client-id=perf-producer-client}                                                  : 0.000

producer-metrics:failed-authentication-total:{client-id=perf-producer-client}                                                 : 0.000

producer-metrics:failed-reauthentication-rate:{client-id=perf-producer-client}                                                : 0.000

producer-metrics:failed-reauthentication-total:{client-id=perf-producer-client}                                               : 0.000

producer-metrics:flush-time-ns-total:{client-id=perf-producer-client}                                                         : 28483262.000

producer-metrics:incoming-byte-rate:{client-id=perf-producer-client}                                                          : 23798.046

producer-metrics:incoming-byte-total:{client-id=perf-producer-client}                                                         : 42905454.000

producer-metrics:io-ratio:{client-id=perf-producer-client}                                                                    : 0.023

producer-metrics:io-time-ns-avg:{client-id=perf-producer-client}                                                              : 23190.800

producer-metrics:io-time-ns-total:{client-id=perf-producer-client}                                                            : 40194793574.000

producer-metrics:io-wait-ratio:{client-id=perf-producer-client}                                                               : 0.963

producer-metrics:io-wait-time-ns-avg:{client-id=perf-producer-client}                                                         : 971064.443

producer-metrics:io-wait-time-ns-total:{client-id=perf-producer-client}                                                       : 1736179052940.000

producer-metrics:io-waittime-total:{client-id=perf-producer-client}                                                           : 1736179052940.000

producer-metrics:iotime-total:{client-id=perf-producer-client}                                                                : 40194793574.000

producer-metrics:metadata-age:{client-id=perf-producer-client}                                                                : 59.390

producer-metrics:metadata-wait-time-ns-total:{client-id=perf-producer-client}                                                 : 534576419.000

producer-metrics:network-io-rate:{client-id=perf-producer-client}                                                             : 670.157

producer-metrics:network-io-total:{client-id=perf-producer-client}                                                            : 1208466.000

producer-metrics:outgoing-byte-rate:{client-id=perf-producer-client}                                                          : 1077183.108

producer-metrics:outgoing-byte-total:{client-id=perf-producer-client}                                                         : 1940970481.000

producer-metrics:produce-throttle-time-avg:{client-id=perf-producer-client}                                                   : 0.000

producer-metrics:produce-throttle-time-max:{client-id=perf-producer-client}                                                   : 0.000

producer-metrics:reauthentication-latency-avg:{client-id=perf-producer-client}                                                : NaN

producer-metrics:reauthentication-latency-max:{client-id=perf-producer-client}                                                : NaN

producer-metrics:record-error-rate:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:record-error-total:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:record-queue-time-avg:{client-id=perf-producer-client}                                                       : 1.342

producer-metrics:record-queue-time-max:{client-id=perf-producer-client}                                                       : 48.000

producer-metrics:record-retry-rate:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:record-retry-total:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:record-send-rate:{client-id=perf-producer-client}                                                            : 998.921

producer-metrics:record-send-total:{client-id=perf-producer-client}                                                           : 1800000.000

producer-metrics:record-size-avg:{client-id=perf-producer-client}                                                             : 1110.000

producer-metrics:record-size-max:{client-id=perf-producer-client}                                                             : 1110.000

producer-metrics:records-per-request-avg:{client-id=perf-producer-client}                                                     : 2.982

producer-metrics:request-latency-avg:{client-id=perf-producer-client}                                                         : 19.554

producer-metrics:request-latency-max:{client-id=perf-producer-client}                                                         : 92.000

producer-metrics:request-rate:{client-id=perf-producer-client}                                                                : 335.009

producer-metrics:request-size-avg:{client-id=perf-producer-client}                                                            : 3215.384

producer-metrics:request-size-max:{client-id=perf-producer-client}                                                            : 15630.000

producer-metrics:request-total:{client-id=perf-producer-client}                                                               : 604233.000

producer-metrics:requests-in-flight:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:response-rate:{client-id=perf-producer-client}                                                               : 335.105

producer-metrics:response-total:{client-id=perf-producer-client}                                                              : 604233.000

producer-metrics:select-rate:{client-id=perf-producer-client}                                                                 : 991.506

producer-metrics:select-total:{client-id=perf-producer-client}                                                                : 1788829.000

producer-metrics:successful-authentication-no-reauth-total:{client-id=perf-producer-client}                                   : 6.000

producer-metrics:successful-authentication-rate:{client-id=perf-producer-client}                                              : 0.000

producer-metrics:successful-authentication-total:{client-id=perf-producer-client}                                             : 6.000

producer-metrics:successful-reauthentication-rate:{client-id=perf-producer-client}                                            : 0.000

producer-metrics:successful-reauthentication-total:{client-id=perf-producer-client}                                           : 0.000

producer-metrics:txn-abort-time-ns-total:{client-id=perf-producer-client}                                                     : 0.000

producer-metrics:txn-begin-time-ns-total:{client-id=perf-producer-client}                                                     : 0.000

producer-metrics:txn-commit-time-ns-total:{client-id=perf-producer-client}                                                    : 0.000

producer-metrics:txn-init-time-ns-total:{client-id=perf-producer-client}                                                      : 0.000

producer-metrics:txn-send-offsets-time-ns-total:{client-id=perf-producer-client}                                              : 0.000

producer-metrics:waiting-threads:{client-id=perf-producer-client}                                                             : 0.000

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node--1}                                    : 0.000

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node--2}                                    : 0.000

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-1}                                     : 8343.031

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-2}                                     : 7824.279

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-3}                                     : 7615.320

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node--1}                                   : 1310.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node--2}                                   : 479.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-1}                                    : 15282716.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-2}                                    : 14232168.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-3}                                    : 13388781.000

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node--1}                                    : 0.000

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node--2}                                    : 0.000

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-1}                                     : 352845.197

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-2}                                     : 340806.310

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-3}                                     : 384678.154

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node--1}                                   : 205.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node--2}                                   : 115.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-1}                                    : 646018156.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-2}                                    : 617214642.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-3}                                    : 677737363.000

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node--1}                                   : NaN

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node--2}                                   : NaN

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-1}                                    : 17.685

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-2}                                    : 18.469

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-3}                                    : 22.745

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node--1}                                   : NaN

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node--2}                                   : NaN

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-1}                                    : 73.000

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-2}                                    : 81.000

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-3}                                    : 92.000

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node--1}                                          : 0.000

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node--2}                                          : 0.000

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-1}                                           : 117.269

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-2}                                           : 110.508

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-3}                                           : 107.213

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node--1}                                      : NaN

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node--2}                                      : NaN

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-1}                                       : 3008.843

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-2}                                       : 3084.004

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-3}                                       : 3587.977

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node--1}                                      : NaN

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node--2}                                      : NaN

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-1}                                       : 15630.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-2}                                       : 15630.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-3}                                       : 15630.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node--1}                                         : 3.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node--2}                                         : 2.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-1}                                          : 215216.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-2}                                          : 200443.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-3}                                          : 188569.000

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node--1}                                         : 0.000

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node--2}                                         : 0.000

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-1}                                          : 117.507

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-2}                                          : 110.201

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-3}                                          : 107.258

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node--1}                                        : 3.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node--2}                                        : 2.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-1}                                         : 215216.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-2}                                         : 200443.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-3}                                         : 188569.000

producer-topic-metrics:byte-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                                 : 1052317.109

producer-topic-metrics:byte-total:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                                : 1896257298.000

producer-topic-metrics:compression-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                          : 1.000

producer-topic-metrics:record-error-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                         : 0.000

producer-topic-metrics:record-error-total:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                        : 0.000

producer-topic-metrics:record-retry-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                         : 0.000

producer-topic-metrics:record-retry-total:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                        : 0.000

producer-topic-metrics:record-send-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                          : 998.921

producer-topic-metrics:record-send-total:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                         : 1800000.000

[root@3c67cc921beb appuser]#

-       Lancement en rarjoutant les parametres de batch size etc..

[root@3c67cc921beb appuser]# kafka-producer-perf-test --topic "tire2-nominal-2.json"  --num-records 18000  --record-size 1024  --throughput 1000  --producer.config bomberder.properties  --producer-props linger.ms=50 compression.type=lz4  batch.size=65536  buffer.memory=67108864   --print-metrics

Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/pki/tls/certs/kafka-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=jks

4955 records sent, 988.0 records/sec (0.96 MB/sec), 162.9 ms avg latency, 1254.0 ms max latency.

5009 records sent, 1000.6 records/sec (0.98 MB/sec), 40.8 ms avg latency, 83.0 ms max latency.

5037 records sent, 999.2 records/sec (0.98 MB/sec), 40.3 ms avg latency, 84.0 ms max latency.

18000 records sent, 999.333777 records/sec (0.98 MB/sec), 74.29 ms avg latency, 1254.00 ms max latency, 43 ms 50th, 334 ms 95th, 885 ms 99th, 1237 ms 99.9th.

Metric Name                                                                                                                     Value

app-info:commit-id:{client-id=perf-producer-client}                                                                           : fdd7d97c55329e51485991b5fccc9bb91e83cf76

app-info:start-time-ms:{client-id=perf-producer-client}                                                                       : 1766068364580

app-info:version:{client-id=perf-producer-client}                                                                             : 7.7.7-ccs

kafka-metrics-count:count:{client-id=perf-producer-client}                                                                    : 149.000

producer-metrics:batch-size-avg:{client-id=perf-producer-client}                                                              : 53191.260

producer-metrics:batch-size-max:{client-id=perf-producer-client}                                                              : 62056.000

producer-metrics:batch-split-rate:{client-id=perf-producer-client}                                                            : 0.000

producer-metrics:batch-split-total:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:buffer-available-bytes:{client-id=perf-producer-client}                                                      : 67108864.000

producer-metrics:buffer-exhausted-rate:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:buffer-exhausted-total:{client-id=perf-producer-client}                                                      : 0.000

producer-metrics:buffer-total-bytes:{client-id=perf-producer-client}                                                          : 67108864.000

producer-metrics:bufferpool-wait-ratio:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:bufferpool-wait-time-ns-total:{client-id=perf-producer-client}                                               : 0.000

producer-metrics:bufferpool-wait-time-total:{client-id=perf-producer-client}                                                  : 0.000

producer-metrics:compression-rate-avg:{client-id=perf-producer-client}                                                        : 1.000

producer-metrics:connection-close-rate:{client-id=perf-producer-client}                                                       : 0.000

producer-metrics:connection-close-total:{client-id=perf-producer-client}                                                      : 0.000

producer-metrics:connection-count:{client-id=perf-producer-client}                                                            : 5.000

producer-metrics:connection-creation-rate:{client-id=perf-producer-client}                                                    : 0.105

producer-metrics:connection-creation-total:{client-id=perf-producer-client}                                                   : 5.000

producer-metrics:connections:{client-id=perf-producer-client, cipher=TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384, protocol=TLSv1.2} : 5

producer-metrics:failed-authentication-rate:{client-id=perf-producer-client}                                                  : 0.000

producer-metrics:failed-authentication-total:{client-id=perf-producer-client}                                                 : 0.000

producer-metrics:failed-reauthentication-rate:{client-id=perf-producer-client}                                                : 0.000

producer-metrics:failed-reauthentication-total:{client-id=perf-producer-client}                                               : 0.000

producer-metrics:flush-time-ns-total:{client-id=perf-producer-client}                                                         : 12859250.000

producer-metrics:incoming-byte-rate:{client-id=perf-producer-client}                                                          : 579.895

producer-metrics:incoming-byte-total:{client-id=perf-producer-client}                                                         : 27545.000

producer-metrics:io-ratio:{client-id=perf-producer-client}                                                                    : 0.017

producer-metrics:io-time-ns-avg:{client-id=perf-producer-client}                                                              : 552252.873

producer-metrics:io-time-ns-total:{client-id=perf-producer-client}                                                            : 794691884.000

producer-metrics:io-wait-ratio:{client-id=perf-producer-client}                                                               : 0.348

producer-metrics:io-wait-time-ns-avg:{client-id=perf-producer-client}                                                         : 11552049.304

producer-metrics:io-wait-time-ns-total:{client-id=perf-producer-client}                                                       : 16623398948.000

producer-metrics:io-waittime-total:{client-id=perf-producer-client}                                                           : 16623398948.000

producer-metrics:iotime-total:{client-id=perf-producer-client}                                                                : 794691884.000

producer-metrics:metadata-age:{client-id=perf-producer-client}                                                                : 17.490

producer-metrics:metadata-wait-time-ns-total:{client-id=perf-producer-client}                                                 : 532808357.000

producer-metrics:network-io-rate:{client-id=perf-producer-client}                                                             : 15.030

producer-metrics:network-io-total:{client-id=perf-producer-client}                                                            : 714.000

producer-metrics:outgoing-byte-rate:{client-id=perf-producer-client}                                                          : 392456.352

producer-metrics:outgoing-byte-total:{client-id=perf-producer-client}                                                         : 18643639.000

producer-metrics:produce-throttle-time-avg:{client-id=perf-producer-client}                                                   : 0.000

producer-metrics:produce-throttle-time-max:{client-id=perf-producer-client}                                                   : 0.000

producer-metrics:reauthentication-latency-avg:{client-id=perf-producer-client}                                                : NaN

producer-metrics:reauthentication-latency-max:{client-id=perf-producer-client}                                                : NaN

producer-metrics:record-error-rate:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:record-error-total:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:record-queue-time-avg:{client-id=perf-producer-client}                                                       : 55.417

producer-metrics:record-queue-time-max:{client-id=perf-producer-client}                                                       : 384.000

producer-metrics:record-retry-rate:{client-id=perf-producer-client}                                                           : 0.000

producer-metrics:record-retry-total:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:record-send-rate:{client-id=perf-producer-client}                                                            : 380.092

producer-metrics:record-send-total:{client-id=perf-producer-client}                                                           : 18000.000

producer-metrics:record-size-avg:{client-id=perf-producer-client}                                                             : 1110.000

producer-metrics:record-size-max:{client-id=perf-producer-client}                                                             : 1110.000

producer-metrics:records-per-request-avg:{client-id=perf-producer-client}                                                     : 51.429

producer-metrics:request-latency-avg:{client-id=perf-producer-client}                                                         : 40.371

producer-metrics:request-latency-max:{client-id=perf-producer-client}                                                         : 1204.000

producer-metrics:request-rate:{client-id=perf-producer-client}                                                                : 7.515

producer-metrics:request-size-avg:{client-id=perf-producer-client}                                                            : 52223.078

producer-metrics:request-size-max:{client-id=perf-producer-client}                                                            : 62131.000

producer-metrics:request-total:{client-id=perf-producer-client}                                                               : 357.000

producer-metrics:requests-in-flight:{client-id=perf-producer-client}                                                          : 0.000

producer-metrics:response-rate:{client-id=perf-producer-client}                                                               : 7.516

producer-metrics:response-total:{client-id=perf-producer-client}                                                              : 357.000

producer-metrics:select-rate:{client-id=perf-producer-client}                                                                 : 30.098

producer-metrics:select-total:{client-id=perf-producer-client}                                                                : 1439.000

producer-metrics:successful-authentication-no-reauth-total:{client-id=perf-producer-client}                                   : 5.000

producer-metrics:successful-authentication-rate:{client-id=perf-producer-client}                                              : 0.105

producer-metrics:successful-authentication-total:{client-id=perf-producer-client}                                             : 5.000

producer-metrics:successful-reauthentication-rate:{client-id=perf-producer-client}                                            : 0.000

producer-metrics:successful-reauthentication-total:{client-id=perf-producer-client}                                           : 0.000

producer-metrics:txn-abort-time-ns-total:{client-id=perf-producer-client}                                                     : 0.000

producer-metrics:txn-begin-time-ns-total:{client-id=perf-producer-client}                                                     : 0.000

producer-metrics:txn-commit-time-ns-total:{client-id=perf-producer-client}                                                    : 0.000

producer-metrics:txn-init-time-ns-total:{client-id=perf-producer-client}                                                      : 0.000

producer-metrics:txn-send-offsets-time-ns-total:{client-id=perf-producer-client}                                              : 0.000

producer-metrics:waiting-threads:{client-id=perf-producer-client}                                                             : 0.000

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node--1}                                    : 18.589

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node--2}                                    : 9.538

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-1}                                     : 162.465

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-2}                                     : 216.476

producer-node-metrics:incoming-byte-rate:{client-id=perf-producer-client, node-id=node-3}                                     : 174.664

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node--1}                                   : 883.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node--2}                                   : 453.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-1}                                    : 7695.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-2}                                    : 10251.000

producer-node-metrics:incoming-byte-total:{client-id=perf-producer-client, node-id=node-3}                                    : 8263.000

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node--1}                                    : 4.042

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node--2}                                    : 1.347

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-1}                                     : 114770.441

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-2}                                     : 155431.488

producer-node-metrics:outgoing-byte-rate:{client-id=perf-producer-client, node-id=node-3}                                     : 123527.802

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node--1}                                   : 192.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node--2}                                   : 64.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-1}                                    : 5436561.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-2}                                    : 7361857.000

producer-node-metrics:outgoing-byte-total:{client-id=perf-producer-client, node-id=node-3}                                    : 5844965.000

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node--1}                                   : NaN

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node--2}                                   : NaN

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-1}                                    : 28.078

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-2}                                    : 58.406

producer-node-metrics:request-latency-avg:{client-id=perf-producer-client, node-id=node-3}                                    : 29.145

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node--1}                                   : NaN

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node--2}                                   : NaN

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-1}                                    : 552.000

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-2}                                    : 1204.000

producer-node-metrics:request-latency-max:{client-id=perf-producer-client, node-id=node-3}                                    : 276.000

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node--1}                                          : 0.063

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node--2}                                          : 0.021

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-1}                                           : 2.174

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-2}                                           : 2.935

producer-node-metrics:request-rate:{client-id=perf-producer-client, node-id=node-3}                                           : 2.346

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node--1}                                      : 64.000

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node--2}                                      : 64.000

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-1}                                       : 52782.146

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-2}                                       : 52963.000

producer-node-metrics:request-size-avg:{client-id=perf-producer-client, node-id=node-3}                                       : 52657.342

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node--1}                                      : 77.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node--2}                                      : 64.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-1}                                       : 62077.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-2}                                       : 62082.000

producer-node-metrics:request-size-max:{client-id=perf-producer-client, node-id=node-3}                                       : 62131.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node--1}                                         : 3.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node--2}                                         : 1.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-1}                                          : 103.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-2}                                          : 139.000

producer-node-metrics:request-total:{client-id=perf-producer-client, node-id=node-3}                                          : 111.000

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node--1}                                         : 0.063

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node--2}                                         : 0.021

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-1}                                          : 2.175

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-2}                                          : 2.935

producer-node-metrics:response-rate:{client-id=perf-producer-client, node-id=node-3}                                          : 2.346

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node--1}                                        : 3.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node--2}                                        : 1.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-1}                                         : 103.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-2}                                         : 139.000

producer-node-metrics:response-total:{client-id=perf-producer-client, node-id=node-3}                                         : 111.000

producer-topic-metrics:byte-rate:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                                 : 393135.698

producer-topic-metrics:byte-total:{client-id=perf-producer-client, topic=tire2-nominal-2.json}                                : 18616941.000

[root@3c67cc921beb appuser]# kafka-producer-perf-test --topic "tire2-nominal-2.json"  --num-records 18000  --record-size 1024  --throughput 1000  --producer.config bomberder.properties  --producer-props linger.ms=0 compression.type=lz4   acks=1 --print-metrics

Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/pki/tls/certs/kafka-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=jks

4996 records sent, 999.0 records/sec (0.98 MB/sec), 31.7 ms avg latency, 758.0 ms max latency.

4999 records sent, 999.8 records/sec (0.98 MB/sec), 6.9 ms avg latency, 13.0 ms max latency.

5003 records sent, 1000.6 records/sec (0.98 MB/sec), 6.8 ms avg latency, 17.0 ms max latency.

18000 records sent, 999.833361 records/sec (0.98 MB/sec), 13.76 ms avg latency, 758.00 ms max latency, 6 ms 50th, 11 ms 95th, 190 ms 99th, 203 ms 99.9th.

Suite du bench

[root@3c67cc921beb appuser]# kafka-producer-perf-test \

>   --topic "tire2-nominal-3.json" \

>   --num-records 1800000 \

>   --record-size 10240 \

>   --throughput 10000 \

>   --producer.config bomberder.properties \

>   --producer-props linger.ms=5 batch.size=32768  acks=1 compression.type=lz4 --print-metrics

Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/pki/tls/certs/kafka-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=jks

[2025-12-18 14:59:12,833] WARN [Producer clientId=perf-producer-client] Error while fetching metadata with correlation id 1 : {tire2-nominal-3.json=LEADER_NOT_AVAILABLE} (org.apache.kafka.clients.NetworkClient)

23871 records sent, 4773.2 records/sec (46.61 MB/sec), 495.7 ms avg latency, 975.0 ms max latency.

32685 records sent, 6535.7 records/sec (63.83 MB/sec), 459.8 ms avg latency, 700.0 ms max latency.

32923 records sent, 6584.6 records/sec (64.30 MB/sec), 455.1 ms avg latency, 654.0 ms max latency.

32975 records sent, 6595.0 records/sec (64.40 MB/sec), 456.4 ms avg latency, 666.0 ms max latency.

32765 records sent, 6553.0 records/sec (63.99 MB/sec), 458.0 ms avg latency, 662.0 ms max latency.

32891 records sent, 6578.2 records/sec (64.24 MB/sec), 455.9 ms avg latency, 659.0 ms max latency.

32775 records sent, 6555.0 records/sec (64.01 MB/sec), 456.0 ms avg latency, 659.0 ms max latency.

32487 records sent, 6497.4 records/sec (63.45 MB/sec), 460.8 ms avg latency, 657.0 ms max latency.

32648 records sent, 6529.6 records/sec (63.77 MB/sec), 460.3 ms avg latency, 677.0 ms max latency.

31663 records sent, 6332.6 records/sec (61.84 MB/sec), 469.0 ms avg latency, 874.0 ms max latency.

32359 records sent, 6471.8 records/sec (63.20 MB/sec), 467.9 ms avg latency, 863.0 ms max latency.

32529 records sent, 6505.8 records/sec (63.53 MB/sec), 460.7 ms avg latency, 665.0 ms max latency.

32399 records sent, 6479.8 records/sec (63.28 MB/sec), 461.8 ms avg latency, 671.0 ms max latency.

31968 records sent, 6393.6 records/sec (62.44 MB/sec), 466.2 ms avg latency, 682.0 ms max latency.

32798 records sent, 6559.6 records/sec (64.06 MB/sec), 457.4 ms avg latency, 659.0 ms max latency.

32485 records sent, 6497.0 records/sec (63.45 MB/sec), 461.4 ms avg latency, 767.0 ms max latency.

31937 records sent, 6387.4 records/sec (62.38 MB/sec), 467.9 ms avg latency, 753.0 ms max latency.

32517 records sent, 6502.1 records/sec (63.50 MB/sec), 459.3 ms avg latency, 675.0 ms max latency.

32656 records sent, 6531.2 records/sec (63.78 MB/sec), 458.2 ms avg latency, 660.0 ms max latency.

32589 records sent, 6516.5 records/sec (63.64 MB/sec), 458.7 ms avg latency, 660.0 ms max latency.

32650 records sent, 6528.7 records/sec (63.76 MB/sec), 456.8 ms avg latency, 669.0 ms max latency.

32540 records sent, 6508.0 records/sec (63.55 MB/sec), 459.0 ms avg latency, 669.0 ms max latency.

32776 records sent, 6555.2 records/sec (64.02 MB/sec), 456.3 ms avg latency, 677.0 ms max latency.

32650 records sent, 6530.0 records/sec (63.77 MB/sec), 458.3 ms avg latency, 675.0 ms max latency.

32460 records sent, 6492.0 records/sec (63.40 MB/sec), 460.7 ms avg latency, 734.0 ms max latency.

32633 records sent, 6522.7 records/sec (63.70 MB/sec), 460.6 ms avg latency, 683.0 ms max latency.

32733 records sent, 6546.6 records/sec (63.93 MB/sec), 459.2 ms avg latency, 668.0 ms max latency.

32352 records sent, 6470.4 records/sec (63.19 MB/sec), 462.3 ms avg latency, 751.0 ms max latency.

32329 records sent, 6464.5 records/sec (63.13 MB/sec), 463.1 ms avg latency, 705.0 ms max latency.

32355 records sent, 6469.7 records/sec (63.18 MB/sec), 464.2 ms avg latency, 685.0 ms max latency.

32779 records sent, 6555.8 records/sec (64.02 MB/sec), 457.3 ms avg latency, 668.0 ms max latency.

32310 records sent, 6462.0 records/sec (63.11 MB/sec), 461.5 ms avg latency, 745.0 ms max latency.

32811 records sent, 6562.2 records/sec (64.08 MB/sec), 458.6 ms avg latency, 673.0 ms max latency.

32779 records sent, 6555.8 records/sec (64.02 MB/sec), 457.2 ms avg latency, 669.0 ms max latency.

32762 records sent, 6551.1 records/sec (63.98 MB/sec), 457.8 ms avg latency, 681.0 ms max latency.

32753 records sent, 6550.6 records/sec (63.97 MB/sec), 457.2 ms avg latency, 671.0 ms max latency.

32781 records sent, 6554.9 records/sec (64.01 MB/sec), 457.3 ms avg latency, 667.0 ms max latency.

32882 records sent, 6576.4 records/sec (64.22 MB/sec), 455.5 ms avg latency, 660.0 ms max latency.

1800000 records sent, 6484.173214 records/sec (63.32 MB/sec), 459.97 ms avg latency, 975.00 ms max latency, 436 ms 50th, 653 ms 95th, 676 ms 99th, 793 ms 99.9th.

-       Mise en place de la security basic sur la schema registry

-       Mise en place secuty basic sur kafka connect mm2 avec exposition https du service rest

Recommandations

-       Integrer un outil de visualisation des topics pour les client comme Lenses

-       A court terme integrer les acls qui sont déjà actives sur les cluster. Moyen term, Integrer le multi tenancy sur les projet avec  une gestion plus fine des acls et a long terme  encore  mettre en place le topics as service ou une plateforme de self service sur les cluster kafka avec dans le blueprint un package (api pour s’interfacer au cluster kafka, une ui de visualisation (lenses ), un cluster kafka avec kafka connect mm2 en addon, Schema registry et rest proxy)

-       Industrialiser le monitoring avec les metriques jmx qui remontent de manière automatique

-       Mettre en place de l’alerting et une supervision complete sur les metriques les plus importantes du point de vue metier et infra du cluster kafka

-       Mettre en place kraft pour baisser les latences obserées sur les productions et consommation

-       Tunner les producer et consumer de mmm2 afin d’avoir une replication plus dynamique et moins latente

-

Ci joint mes rapports des jours 1 a 3
 
1.	Contexte et Objectifs de la Journée
Installation actuelle sur tous les clusters 
Paramètre	Valeur relevée
Version Kafka	 7.7.3
Nombre de brokers	3 brokers
Coordination (ZK)	Zookeeper
Espace disque total	250 Go
RAM par broker	32 Go
vCPU par broker	4

1.1 Contexte de la Mission
Transactis dispose de plusieurs clusters applicatifs répartis par code applicatifs mais dans notre cas seulement deux clusters Kafka distincts servant des besoins métiers différents  nous concernent:
Cluster	Fonction
Kafka NEMO	Échanges inter-applicatifs – Communication entre applications distinctes
Kafka Applicatif	Échanges intra-applicatifs – Communication interne à une application
La mission vise à auditer l'implémentation de MirrorMaker 2 pour la réplication entre ces clusters, avec un focus sur les performances et la conformité aux exigences SLA (indisponibilité < 1h/an).
1.2 Objectifs du Jour 1
1.	Validation de l'architecture Kafka globale (clusters NEMO et Applicatif)
2.	Audit de l'implémentation actuelle de MirrorMaker 2
3.	Identification des écarts par rapport aux bonnes pratiques de production
4.	Mise en place d'un environnement de test de référence
2. Travaux Réalisés – Matinée (9h-12h)
2.1 Revue de l'Architecture Kafka Globale
Analyse approfondie des architectures déployées, incluant :
•	Modes d'installation : Revue des artifacts de déploiement et des pipelines CI/CD
•	Architecture NEMO + Inter-cluster : Cartographie des flux de données entre les deux clusters

 

•	Cartographie complète : Documentation des topologies déployées
2.2 Analyse du Workflow de Création de Cluster
Le processus de provisionnement d'un cluster Kafka suit le workflow suivant :
1.	Demande client : L'équipe projet sollicite l'équipe Plateforme Transactis
2.	Transmission documentation : Envoi du template de configuration + documentation de la dernière release
3.	Formulaire Jenkins : Le client remplit les paramètres de déploiement (LogmTenantId, GitCredentialId, CustomConfigRepositoryUrl, S3Endpoint, SGCPAccountName, etc.)
4.	Provisioning : Terraform provisionne les VMs sur OpenStack, Ansible configure les composants, Jenkins orchestre le pipeline
5.	Livraison : Transmission des comptes techniques au client pour production/consommation

 
2.3 Enrichissement des Métriques JMX
Travail sur l'exposition des métriques via Java Agent Exporters pour les composants suivants :
Composant	Métriques Clés
Brokers Kafka	MessagesInPerSec, BytesInPerSec, UnderReplicatedPartitions, ISRShrinkRate
ZooKeeper	AvgRequestLatency, OutstandingRequests, NumAliveConnections
Kafka Connect MM2	connector-task-metrics, source-record-poll-rate, sink-record-send-rate
3. Travaux Réalisés – Après-midi (13h-17h)
3.1 Installation Kafka avec JMX Exporters
Mise en place d'une installation Kafka de référence avec exposition complète des métriques JMX via Prometheus JMX Exporter. Cette configuration servira de base pour les tests de performance.
3.2 Configuration Kafka Connect Distribué
Configuration de Kafka Connect en mode distribué (production-ready), incluant :
•	Configuration du fichier connect-distributed.properties
•	Topics internes Connect avec RF=3 (_mm2-connect-offsets, _ mm2-connect-configs, _ mm2-connect-status)
•	Paramétrage du rebalancing et heartbeat
3.3 Création de l'Environnement de Test
Un environnement de test complet a été déployé pour servir de référence :
4. Architecture de l'Environnement de Test
Composant	Configuration	Répartition
Cluster Kafka	3 Brokers	3 AZ (Paris1, Paris2, North1)
ZooKeeper	3 Nœuds (Quorum)	3 AZ (Paris1, Paris2, North1)
Kafka Connect / MM2	3 Workers (Distribué)	3 AZ (Paris1, Paris2, North1)
Métriques JMX	Java Agent Exporters	Tous composants
 
5. Problèmes et Écarts Constatés
L'audit a permis d'identifier les écarts suivants par rapport aux bonnes pratiques de production :
#	Constat	Impact	Criticité
1	Pas de gestion des ACLs	Playbook Ansible ne crée pas les ACLs. Accès non restreint aux topics.	CRITIQUE
2	Métriques JMX non exposées	Aucune visibilité sur les performances. Diagnostic incidents impossible.	HAUTE
3	Problèmes déploiement clusters	Incohérences dans le pipeline Terraform/Ansible.	CRITIQUE
4	MM2 en mode standalone	Single Point of Failure. Pas de haute disponibilité.	CRITIQUE
5	Composants collocalisés	MM2/Connect sur mêmes VMs que brokers. Contention ressources.	HAUTE
6. Analyse Spécifique MirrorMaker 2
6.1 Modes d'Installation Disponibles
Deux modes d'installation sont possibles pour MirrorMaker 2 :
Mode 1 : Binaire Standalone (connect-mirror-maker.sh)
Constat actuel : C'est le mode actuellement déployé chez Transactis.
Inconvénients	Avantages
•	Single Point of Failure
•	Pas de haute disponibilité native
•	Redémarrage requis pour changement config
•	Scaling manuel uniquement
•	Pas de rebalancing automatique	•	Installation simple
•	Moins de composants à gérer
Mode 2 : Connect-Based avec Plugins (RECOMMANDÉ)
Solution cible : Utilisation de Kafka Connect distribué avec les plugins MirrorMaker 2.
Avantages	Plugins MM2
•	Haute disponibilité native
•	Rebalancing automatique des tâches
•	Configuration via API REST (sans redémarrage)
•	Tuning producer/consumer à chaud
•	Scaling horizontal transparent
•	Monitoring JMX intégré	•	MirrorSourceConnector
◦	Réplication des données
•	MirrorCheckpointConnector
◦	Synchronisation des offsets
•	MirrorHeartbeatConnector
◦	Détection de vivacité
6.2 Workflow de Création MM2 (Cible)
Le workflow de création d'un cluster MirrorMaker 2 recommandé est le suivant :
1.	Pipeline Terraform : Provisionnement des nœuds Connect avec paramètres
2.	Installation Connect : Déploiement Kafka Connect distribué avec plugins MM2
3.	Configuration via API : Instanciation des connecteurs via API REST Connect
Note importante : Le owner du MM2 doit être le même que celui du cluster de destination (règle fondamentale MM2).


Architecture Cible : 

 

Les déploiements MirrorMaker «côté target» se justifient surtout par des contraintes de sécurité réseau, de gouvernance et parfois d’ops, pas par une obligation technique stricte.

7. Audit des Configurations Brokers
Analyse des paramètres de configuration actuels des brokers Kafka :
Paramètre	Valeur	Éval.	Recommandation
num.network.threads	3	⚠	Recommandé: 8-12
num.io.threads	8	✓	OK
default.replication.factor	3	✓	RF=3 en prod
min.insync.replicas	2	✓	OK avec RF=3
transaction.state.log.min.isr	3	⚠	Recommandé: 2
num.recovery.threads.per.data.dir	1	⚠	Recommandé: 4
group.initial.rebalance.delay.ms	0	⚠	Recommandé: 3000
log.retention.hours	168	✓	7 jours
auto.create.topics.enable	false	✓	Best practice
8. Travaux en Cours et Prévus (Jour 2)
8.1 Travaux en Cours
•	Finalisation de l'environnement de test avec métriques JMX
•	Documentation des configurations de référence
8.2 Activités Prévues Jour 2
Activité	Livrable
Installation Kafka, ZooKeeper, Connect avec métriques JMX	Environnement de référence
Test installation MirrorMaker 2 mode Connect-based	Connecteurs MM2 opérationnels
Setup Prometheus + Grafana	Dashboards monitoring temps réel
 
9. Diagrammes Techniques
Les diagrammes suivants sont fournis pour intégration dans la documentation technique.
9.1 Workflow Complet de Création d'un Cluster Kafka
 
 
9.2 Workflow MirrorMaker 2 (Cible)
 

Rédigé par : Mafouze Koto – Consultant Senior Data Platform, Octamis
Date : 15 décembre 2025


1. Rappel du Contexte (Jour 1 → Jour 2)
1.1 Objectifs Initiaux de la Mission
La mission d'audit Kafka MirrorMaker 2 pour Transactis s'inscrit dans un programme de 4 jours avec les objectifs suivants :
Lot	Description	Durée
Lot 1	Validation de l'architecture Kafka MirrorMaker	0.5 jour
Lot 2	Audit de l'implémentation MirrorMaker 2	0.5 jour
Lot 3	Tests de performance et de résilience	1 jour
Lot 4	Documentation et recommandations	1 jour

Contrainte SLA cible : Moins de 1 heure de downtime annuel (disponibilité > 99.989%)
1.2 Bilan Jour 1
Le Jour 1 a été consacré à :
•	La revue de l'architecture des clusters Kafka (NEMO et Applicatif)
•	L'analyse des configurations des brokers et de ZooKeeper
•	L'identification des premières non-conformités (absence d'ACLs, métriques JMX non exposées, collocation de composants)
•	La préparation de l'environnement de test
1.3 Transition vers le Jour 2
Le Jour 2 marque la transition vers :
•	La mise en place de l'infrastructure d'observabilité (prérequis aux tests de performance)
•	La validation de l'exposition des métriques JMX pour tous les composants
•	L'exécution des premiers tests de performance fonctionnels
 
2. Travaux Réalisés - Matin
2.1 Tests Fonctionnels d'Exposition des Métriques JMX
Des tests de validation ont été réalisés pour vérifier l'accessibilité des métriques via les endpoints HTTP exposés par les JMX Exporters.
Composant	Endpoint Testé	Protocole	Statut
ZooKeeper	http://<host>:<port>/metrics	HTTP	Validé
Kafka Brokers	http://<host>:<port>/metrics	HTTP	Validé
Kafka Connect (MM2)	http://<host>:<port>/metrics	HTTP	Validé

Méthodologie de validation :
•	Requête HTTP GET sur l'endpoint /metrics
•	Vérification du format de sortie Prometheus (text/plain; version=0.0.4)
•	Contrôle de la présence des métriques clés attendues

Métriques clés vérifiées par composant :
Composant	Métriques Clés Attendues
ZooKeeper	zk_avg_latency, zk_outstanding_requests, zk_num_alive_connections
Kafka Broker	kafka_server_brokertopicmetrics_*, kafka_controller_*, kafka_network_requestmetrics_*
Kafka Connect	kafka_connect_connector_*, kafka_connect_worker_*, 
2.2 Configuration de Prometheus pour le Scraping
Une instance Prometheus a été configurée pour collecter les métriques des composants distants.
Approche retenue : Déploiement d'un environnement Docker Compose local permettant de scraper les cibles distantes (clusters Kafka de production/test) suivant l’architecture ci-dessous: 
 
Justification technique :
•	Isolation de l'infrastructure de monitoring
•	Flexibilité de configuration sans impact sur les environnements cibles
•	Possibilité de tester les configurations avant déploiement en production
2.3 Intégration de Node Exporter
Node Exporter a été intégré dans les scripts de déploiement existants afin de collecter les métriques au niveau système d'exploitation.
Objectif : Obtenir une visibilité sur les ressources des nœuds hébergeant les composants Kafka.

Métriques OS collectées via Node Exporter :
Catégorie	Métriques Clés
CPU	node_cpu_seconds_total, node_load1, node_load5, node_load15
Mémoire	node_memory_MemTotal_bytes, node_memory_MemAvailable_bytes
Disque	node_disk_io_time_seconds_total, node_filesystem_avail_bytes
Réseau	node_network_receive_bytes_total, node_network_transmit_bytes_total
 
3. Travaux Réalisés - Après-midi
3.1 Déploiement de Schema Registry avec JMX Exporter
Le composant Schema Registry a été déployé avec l'exposition des métriques JMX.
Configuration appliquée :
•	JMX Exporter intégré au processus Schema Registry
•	Endpoint /metrics exposé sur un port dédié
•	Métriques disponibles au format Prometheus

Métriques Schema Registry exposées :
Catégorie	Métriques
Requêtes	kafka_schema_registry_jersey_metrics_*
Sérialisation	kafka_schema_registry_serializer_*
JVM	jvm_memory_*, jvm_gc_*, jvm_threads_*
3.2 Configuration Prometheus Complète
La configuration Prometheus a été finalisée pour intégrer l'ensemble des composants du cluster source.
Composant	Nombre d'Instances	Statut Scraping
Kafka Brokers	3	Opérationnel
ZooKeeper	3	Opérationnel
Kafka Connect (MM2)	2	Opérationnel
Schema Registry	3	Opérationnel
Node Exporter	N instances	Opérationnel
3.3 Validation de Bout en Bout
Une validation complète de la chaîne de remontée des métriques a été réalisée.
Points de contrôle validés :
•	Accessibilité de chaque endpoint JMX Exporter
•	Scraping effectif par Prometheus (vérification via l'interface /targets)
•	Persistance des métriques dans Prometheus (requêtes PromQL de validation)
•	Cohérence des données (absence de gaps, cardinalité correcte)
3.4 Tests de Performance de Type Production
Des tests de performance fonctionnels ont été exécutés avec des résultats concluants.
Statut : Tests fonctionnels validés

Note : Les résultats chiffrés détaillés (throughput, latence, etc.) n'ont pas été documentés lors de cette session. Une campagne de tests formalisée avec mesures précises est planifiée.
 
4. Architecture d'Observabilité Mise en Place
4.1 Vue d'Ensemble
L'architecture d'observabilité déployée suit le pattern standard Prometheus/Grafana avec les composants suivants :
Couche	Composant	Rôle
Collection	JMX Exporter	Exposition des métriques JVM/Kafka au format Prometheus
Collection	Node Exporter	Exposition des métriques OS
Agrégation	Prometheus	Scraping, stockage time-series, requêtes PromQL
Visualisation	Grafana	Dashboards, alerting (préparation)
4.2 Flux de Métriques par Composant
Kafka Brokers :
•	JMX Exporter exposant les MBeans Kafka
•	Métriques clés : kafka.server:*, kafka.controller:*, kafka.network:*, kafka.log:*
•	Intervalle de scrape : 15 secondes

ZooKeeper :
•	JMX Exporter + métriques natives ZooKeeper (Four Letter Words)
•	Métriques clés : latence, connexions, requêtes en attente, état du quorum

Kafka Connect / MirrorMaker 2 :
•	JMX Exporter exposant les métriques Connect et MirrorSourceConnector
•	Métriques clés : kafka.connect.mirror:*, kafka.connect.connector:*, kafka.connect.worker:*


Schema Registry :
•	JMX Exporter intégré
•	Métriques clés : requêtes HTTP, latence sérialisation/désérialisation
4.3 Préparation à l'Intégration Grafana
L'intégration Grafana est préparée mais non finalisée à ce stade.
Dashboards prévus :
Dashboard	Contenu
Kafka Cluster Overview	Santé globale, throughput, partitions, ISR
Broker Details	Métriques par broker, request handlers, network threads
MirrorMaker 2	Lag de réplication, latence, record-count, erreurs
ZooKeeper	Latence, sessions, état du quorum
Infrastructure	Métriques Node Exporter (CPU, RAM, disque, réseau)
 
5. Tests Réalisés
5.1 Validation des Métriques
Test	Description	Résultat
Disponibilité endpoints	Vérification HTTP 200 sur tous les /metrics	Validé
Format Prometheus	Vérification du format text/plain exposition	Validé
Métriques clés présentes	Contrôle des métriques critiques par composant	Validé
Scraping Prometheus	Vérification des targets UP dans Prometheus	Validé
Cohérence temporelle	Absence de gaps dans les séries temporelles	Validé
5.2 Tests de Charge et de Performance
Des tests de charge ont été réalisés en utilisant les outils suivants :
Outil	Type	Utilisation
kafka-producer-perf-test	CLI Kafka	Test de throughput production
kafka-consumer-perf-test	CLI Kafka	Test de throughput consommation
Producer Bomber	Outil custom/tiers	Génération de charge production
Consumer Bomber	Outil custom/tiers	Génération de charge consommation

Statut des tests : Fonctionnellement concluants
Note : Les métriques quantitatives (messages/seconde, latence P99, etc.) n'ont pas été formellement documentées lors de cette session. Une campagne de mesures structurée est requise pour alimenter le rapport de performance.

6. Problèmes Rencontrés
6.1 Problèmes de Certificats sur les Brokers Source
Description :
Des problèmes liés aux certificats TLS ont été rencontrés sur les brokers du cluster source en production.  
Composants impactés :
•	Brokers Kafka (cluster source)
Impact identifié :
•	Perturbation potentielle des connexions sécurisées
•	Nécessité de validation des certificats
Résolution : 
•	Utilisation du bon certificat dans les propriétés producer 
6.2 Contraintes Réseau lors de la Mise en Place de l'Environnement de Test
Description :
Des contraintes réseau ont été rencontrées lors du déploiement de l'environnement de test.
Impact identifié :
•	Complexification de la mise en place de l'infrastructure de test
•	Potentiels ajustements de configuration réseau requis
6.3 Synthèse des Problèmes
Problème	Sévérité	Statut	Action
Certificats Clients 	Moyenne	Non résolu	Documentation
Contraintes réseau env. test	Moyenne	Contourné	Documentation

7. Simulation et Environnements de Test
7.1 Simulation via Docker
Un environnement de simulation a été mis en place via Docker pour :
•	Tester les configurations de monitoring de manière isolée
•	Valider les intégrations avant déploiement sur les environnements cibles
•	Disposer d'un environnement reproductible

Composants simulés :
•	Stack Prometheus (scraping distant vers environnements réels)
•	Configuration des JMX Exporters
7.2 Déploiement JMX Exporter pour Schema Registry
Le JMX Exporter a été configuré et déployé pour le composant Schema Registry dans le cadre de cette simulation.
Objectif :
•	Valider la configuration JMX Exporter avant déploiement production
•	Identifier les métriques pertinentes à collecter
•	Tester l'intégration avec Prometheus
7.3 Objectifs de la Simulation
Objectif	Description	Statut
Validation configs	Tester prometheus.yml avant déploiement	Atteint
Identification métriques	Lister les métriques disponibles par composant	Atteint
Test intégration	Valider la chaîne complète de collecte	Atteint
Documentation	Produire les configurations de référence	En cours


8. Synthèse
8.1 Travaux Accomplis - Jour 2
Domaine	Travaux	Statut
Observabilité	Exposition JMX (ZK, Brokers, Connect, SR)	Terminé
Observabilité	Configuration Prometheus complète	Terminé
Observabilité	Intégration Node Exporter	Terminé
Tests	Validation fonctionnelle des métriques	Terminé
Tests	Tests de performance fonctionnels	Terminé
Simulation	Environnement Docker pour tests	Opérationnel

— Fin du rapport —

Rédigé par	Mafouze Koto Consultant Octamis
Date	17 décembre 2025
Version	1.0
Classification	CONFIDENTIEL

 	 
1.	Rappel du Contexte 
1.1	Objectifs Initiaux de la Mission 
La mission d'audit s'inscrit dans un programme de 4 jours : 
Lot 	Description 	Duree 
Lot 1 	Validation de l'architecture Kafka 
MirrorMaker 	0.5 jour 
Lot 2 	Audit de l'implementation MirrorMaker 2 	0.5 jour 
Lot 3 	Tests de performance et de resilience 	1 jour 
Lot 4 	Documentation et recommandations 	1 jour 
Contrainte SLA cible : Moins de 1 heure de downtime annuel (disponibilite > 99.989%) 
1.2	Progression Jour 1 - Jour 3 
Jour 	Phase 	Activites Principales 
Jour 1 	Architecture et 
Audit 	Revue architecture, identification ecarts, preparation environnement test 
Jour 2 	Observabilite 	Deploiement stack monitoring 
(Prometheus/Grafana), validation metriques 
JMX 
Jour 3 	Performance 	Lancement connecteurs MM2, tests de charge, application optimisations 
2.	Travaux Realises 
2.1	Lancement des Connecteurs MirrorMaker 2 
Les trois connecteurs MirrorMaker 2 ont ete instancies via l'API REST Kafka Connect : 
Connecteur 	Role 	Statut 
MirrorSourceConnector 	Replication des donnees source vers target 	Operationnel 
MirrorCheckpointConnector	 Synchronisation des offsets consumer groups 	Operationnel 
MirrorHeartbeatConnector 	Detection de la vivacite du flux de replication 	Operationnel 
Mode de deploiement : Connect-based distribue (3 workers) 
2.2	Stabilisation des Dashboards Grafana 
Les dashboards Grafana ont ete ajustes pour permettre une visualisation par cluster : 
Dashboard 	Contenu 	Granularite 
Kafka Cluster Overview 	Throughput, partitions, ISR, leaders 	Par cluster 
Broker Metrics 	Request handlers, network threads, I/O 	Par broker 
ZooKeeper Metrics 	Latence, sessions, quorum state 	Par noeud ZK 
Kafka Connect / MM2 	Lag replication, task status, record count 	Par connecteur 
Infrastructure 	CPU, RAM, disque, reseau 
(Node Exporter) 	Par host 
 	 
3.	Campagne de Tests de Performance 
3.1	Outils Utilises 
Outil 	Type 	Usage 
kafka-producer-perftest 	CLI Kafka natif 	Generation de charge production avec metriques integrees 
Producer Bomber 	Outil de charge 	Production de messages avec configuration TLS/SASL 
3.2	Configuration Commune des Tests 
Parametre 	Valeur 
Topic cible 	test-prometheus.generated-data-01.json 
Nombre de messages 	1 800 000 
Taille message 	1024 bytes (1 KB) 
Configuration producteur 	bomberder.properties (TLS/SASL active) 
3.3	Test 1 - Throughput Plafonne (1000 msg/s) 
Objectif : Mesurer la latence et la stabilite sous charge controlee. 
Parametres : --throughput 1000 Resultats Observes : 
Metrique 	Valeur 
Throughput effectif 	999.98 records/sec 
Debit 	0.98 MB/sec 
Latence moyenne 	21.41 ms 
Latence maximale 	889.00 ms 
Percentile 50 (mediane) 	23 ms 
Percentile 95 	28 ms 
Percentile 99 	32 ms 
Percentile 99.9 	63 ms 
Analyse Factuelle : 
•	Le throughput effectif correspond au throughput demande (1000 msg/s), indiquant que le cluster absorbe cette charge sans saturation. 
•	La latence moyenne de 21.41 ms est stable sur l'ensemble du test. 
•	L'ecart entre P99 (32 ms) et P99.9 (63 ms) indique des pics de latence occasionnels mais contenus. 
•	La latence maximale de 889 ms correspond vraisemblablement a un evenement ponctuel (GC, rebalancing, ou pic ZooKeeper). 
3.4	Test 2 - Throughput Non Plafonne (Max) 
Objectif : Determiner le throughput maximal atteignable et observer le comportement sous charge maximale. Parametres : --throughput -1 (pas de limite) Resultats Observes : 
Metrique 	Valeur 
Throughput effectif 	9 308.48 records/sec 
Debit 	9.09 MB/sec 
Latence moyenne 	3 247.29 ms 
Latence maximale 	4 309.00 ms 
Percentile 50 (mediane) 	3 000 ms 
Percentile 95 	4 160 ms 
Percentile 99 	4 236 ms 
Percentile 99.9 	4 286 ms 
Analyse Factuelle : 
•	Le throughput maximal atteint est de ~9 300 records/sec (~9 MB/sec). 
•	La latence moyenne augmente d'un facteur ~150x par rapport au Test 1 (3 247 ms vs 21 ms). 
•	Les percentiles sont tres proches (P50 a P99.9 dans une fourchette de 1 286 ms), indiquant une latence elevee et constante. 
•	Ce comportement suggere une saturation d'un composant du chemin de donnees. 
3.5	Analyse Comparative Test 1 vs Test 2 
Metrique 	Test 1 (1000 msg/s) 	Test 2 (max) 	Facteur 
Throughput 	1 000 rec/s 	9 308 rec/s 	x9.3 
Debit 	0.98 MB/s 	9.09 MB/s 	x9.3 
Latence moyenne 	21.41 ms 	3 247 ms 	x151 
Latence P50 	23 ms 	3 000 ms 	x130 
Latence P99 	32 ms 	4 236 ms 	x132 
Conclusions Factuelles : 
1.	Le plafonnement du throughput ameliore significativement la latence. 
2.	Le cluster peut atteindre ~9 MB/sec en throughput brut, mais au prix d'une latence inacceptable pour la production. 
3.	Le point d'equilibre throughput/latence se situe probablement entre 1 000 et 9 000 msg/s. 
4.	Des tests intermediaires sont necessaires pour identifier le throughput optimal. 
 	 
4.	Observations Transverses 
4.1	Synthese des Observations 
Observation 	Valeur Mesuree 	Source 
Latence ZooKeeper moyenne 	~80 ms 	Dashboard Grafana 
Utilisation CPU brokers 	~25% 	Node Exporter / 
Grafana 
Throughput entree messages 	Correct 	kafka-producer-perftest 
Latence production (Test 2) 	Elevee (>3s) 	kafka-producer-perftest 
4.2	Correlation des Metriques 
Composant 	Observation 	Correlation Potentielle 
Kafka Brokers 	CPU a 25% 	Les brokers ne sont pas 
CPU-bound 
ZooKeeper 	Latence ~80 ms 	Contribution possible a la latence 
Reseau / TLS 	Non mesure 	Overhead TLS/SASL potentiel 
Disque 	Non mesure 	I/O disque a investiguer 
5.	Optimisations Appliquees sur les Brokers 
5.1	Parametres Threads (Adapte pour 4 vCPU) 
Parametre 	Avant 	Apres 	Justification 
num.network.threads 	3 	4 	Alignement sur nb vCPU 
num.io.threads 	8 	8 	Maintenu (2x vCPU) 
Parametre 	Avant 	Apres 	Justification 
num.replica.fetchers 	1 	2 	Catch-up replication 
num.recovery.threads.per.data.dir	 	1 	2 	Recovery accelere 
5.2	Parametres Buffers et Socket 
Parametre 	Avant 	Apres 	Justification 
socket.send.buffer.bytes 	102 KB 	1 MB 	Optim. reseau interne 
socket.receive.buffer.bytes 	102 KB 	1 MB 	Optim. reseau interne 
replica.socket.receive.buffer.bytes	 	(defaut) 	1 MB 	Buffer replication
replica.fetch.max.bytes 	(defaut) 	10 MB 	Taille fetch replication 
5.3	Parametres ZooKeeper 
Parametre 	Avant 	Apres 	Justification 
zookeeper.connection.timeout.ms	 	6 000 	18 000 	Tolerance latences ZK 
zookeeper.session.timeout.ms 	(defaut) 	18 000 	Coherence timeouts 
 	 
6.	Impact Observe des Optimisations 
6.1	Effets Attendus 
Optimisation 	Effet Attendu 
Augmentation socket buffers 	Reduction latence reseau, meilleur throughput 
num.replica.fetchers=2 	Reduction du lag de replication 
num.recovery.threads=2 	Recovery plus rapide apres redemarrage 
Timeouts ZK augmentes 	Moins de deconnexions intempestives 
6.2	Effets Mesures 
Les données seront recoltées au jour 4 
6.3	Limites de l'Analyse 
Limite 	Description 
Chronologie 	Tests executes avant optimisations 
Baseline manquante 	Pas de mesure "avant/apres" sur la meme charge 
Metriques partielles 	I/O disque et reseau non mesures 
7.	Analyse ZooKeeper 
7.1	Latence Observee 
Metrique 	Valeur 	Evaluation 
Latence moyenne ZK 	~80 ms 	Elevee 
Reference (best practice) 	<10 ms 	Cible optimisee 
7.2	Hypotheses Techniques (Non Verifiees) 
Les hypotheses suivantes necessitent une investigation approfondie : 
Hypothese 	Verification Requise 
Contention disque sur les noeuds ZK 	Metriques I/O disque (iostat, node_exporter) 
Collocation ZK avec autres composants 	Verifier l'isolation des ressources 
Configuration JVM ZK non optimisee 	Audit des parametres JVM (heap, GC) 
Latence reseau inter-noeuds 	Mesure RTT entre les 3 AZ 
7.3	Pistes d'Amelioration ZooKeeper 
Action 	Priorite 	Complexite 
Isolation des noeuds ZK (dedicated hosts) 	Haute 	Moyenne 
Optimisation JVM ZK (heap sizing, 
GC) 	Haute 	Faible 
Disques dedies pour ZK data/logs 	Haute 	Moyenne 
Migration vers KRaft (long terme) 	Basse 	Elevee 
 	 
8.	Axes d'Amelioration Identifies 
8.1	Configuration Producteurs 
Les parametres producteur suivants doivent etre evalues : 
Parametre 	Impact 	Recommandation 
acks 	Durabilite vs latence 	acks=all pour production 
linger.ms 	Batching 	Augmenter (5-10 ms) 
batch.size 	Taille batch 	Augmenter (32KB-64KB) 
compression.type 	Bande passante 	snappy ou lz4 
8.2	Ajustements Reseau / TLS 
Axe 	Action 	Priorite 
Overhead TLS 	Mesurer l'impact TLS sur la latence 	Haute 
Cipher suites 	Utiliser des ciphers performants 
(AES-GCM) 	Moyenne 
Session caching TLS 	Activer le cache de sessions 	Moyenne 
9.	Travaux a Poursuivre 
9.1	Jour 4 - Activites Planifiees 
Activite 	Livrable 
Tests consommateurs 	Metriques consumer-perf-test 
Tests replication MM2 bout-enbout 	Metriques MirrorSourceConnector 
Tests post-optimisations 	Comparatif avant/apres 
Tests sous charge prolongee 	Rapport stabilite 
9.2	Alerting Base sur SLO 
SLO 	Seuil 	Alerte 
Latence production 
P99 	< 100 ms 	Critical si > 100 ms / 5 min 
Lag replication MM2 	< 1000 messages 	Warning > 1000, Critical > 
10000 
Under-replicated partitions 	= 0 	Critical si > 0 / 2 min 
 	  
10.	Diagrammes Techniques 
Les diagrammes suivants sont fournis au format Mermaid pour integration dans la documentation technique. 
10.1	Flux de Production et Replication MM2 
 
10.2	Chaine de Metriques Performance 
  
10.3	Scenario de Test de Performance  
  
--- Fin du rapport --- 
 
Redige par 	Mafouze Koto - Consultant Senior Data Platform, 
Octamis 
Date 	17 decembre 2025 
Version 	1.0 
Classification 	CONFIDENTIEL
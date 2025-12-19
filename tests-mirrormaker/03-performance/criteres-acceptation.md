# Critères d'Acceptation - Tests de Performance MirrorMaker 2

## Objectif

Définir les critères objectifs et mesurables permettant de valider ou invalider les résultats des tests de performance, en lien direct avec les exigences du SLA client.

---

## Pré-requis

- [ ] Baseline établie (`02-baseline/`)
- [ ] Métriques à surveiller définies (`metriques-a-surveiller.md`)
- [ ] Valeurs cibles validées avec le client

---

## 1. Rappel des Exigences SLA

| Exigence | Valeur | Traduction Opérationnelle |
|----------|--------|---------------------------|
| Disponibilité annuelle | 99.9886% | < 1h d'indisponibilité/an |
| Temps maximal d'interruption | 1h/an | Budget de 60 minutes |
| RPO (Recovery Point Objective) | `${RPO_SECONDS}` sec | Perte de données max |
| RTO (Recovery Time Objective) | `${RTO_MINUTES}` min | Temps de restauration max |

---

## 2. Critères d'Acceptation Globaux

### 2.1 Critères Obligatoires (MUST)

| ID | Critère | Métrique | Seuil OK | Seuil KO | Bloquant |
|----|---------|----------|----------|----------|----------|
| **CA-01** | Réplication complète | Messages source = Messages cible | Différence = 0 | Différence > 0 | OUI |
| **CA-02** | Pas de perte de données | Messages perdus | 0 | > 0 | OUI |
| **CA-03** | Latence acceptable | Latence E2E P99 | < `${MAX_LATENCY_P99_MS}` ms | > `${MAX_LATENCY_P99_MS}` ms | OUI |
| **CA-04** | Lag maîtrisé | Lag MM2 stable | < `${MAX_LAG_RECORDS}` records | > `${MAX_LAG_RECORDS}` croissant | OUI |
| **CA-05** | Stabilité MM2 | État connecteurs | RUNNING 100% | FAILED ou restart | OUI |
| **CA-06** | Pas d'erreurs critiques | Erreurs MM2/Kafka | 0 erreurs critiques | > 0 erreurs critiques | OUI |

### 2.2 Critères Importants (SHOULD)

| ID | Critère | Métrique | Seuil OK | Seuil Acceptable | Seuil KO |
|----|---------|----------|----------|------------------|----------|
| **CA-07** | Throughput nominal | Débit soutenu | ≥ `${NOMINAL_THROUGHPUT_MSG_SEC}` msg/s | 80-100% nominal | < 80% nominal |
| **CA-08** | Throughput pic | Débit burst | ≥ `${BURST_THROUGHPUT_MSG_SEC}` msg/s | 80-100% cible | < 80% cible |
| **CA-09** | Rattrapage rapide | Temps de catch-up | < `${MAX_CATCHUP_TIME}` min | 1-2x cible | > 2x cible |
| **CA-10** | Ressources maîtrisées | CPU brokers | < 70% | 70-85% | > 85% |
| **CA-11** | Mémoire stable | Heap JVM | < 80% | 80-90% | > 90% |
| **CA-12** | Endurance | Stabilité 8h | Métriques stables | Drift < 10% | Drift > 10% ou crash |

### 2.3 Critères Souhaitables (NICE TO HAVE)

| ID | Critère | Métrique | Cible |
|----|---------|----------|-------|
| **CA-13** | Latence excellente | Latence P50 | < 500 ms |
| **CA-14** | Marge de capacité | Throughput max vs nominal | > 2x |
| **CA-15** | GC optimisé | Pause GC max | < 200 ms |

---

## 3. Critères par Scénario de Test

### 3.1 PERF-01 : Charge Nominale

| Critère | Métrique | Seuil PASS | Seuil FAIL |
|---------|----------|------------|------------|
| Throughput maintenu | msg/sec | ± 5% de `${NOMINAL_THROUGHPUT_MSG_SEC}` | Écart > 10% |
| Lag stable | records | < 1000 records | > 5000 ou croissant |
| Latence P99 | ms | < `${MAX_LATENCY_P99_MS}` ms | > `${MAX_LATENCY_P99_MS}` ms |
| Erreurs | count | 0 | > 0 |
| CPU moyen | % | < 50% | > 70% |
| Durée complète | minutes | 60 min sans interruption | Interruption |

**Verdict PERF-01 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | Tous critères verts |
| ⚠️ PASS CONDITIONNEL | 1-2 critères orange, 0 rouge |
| ❌ FAIL | 1+ critère rouge |

### 3.2 PERF-02 : Montée en Charge

| Palier | Throughput | Critère Lag | Critère Latence | Critère CPU |
|--------|------------|-------------|-----------------|-------------|
| P1 (1x) | `${NOMINAL_RATE}` | < 1000 | < 100ms P99 | < 50% |
| P2 (1.5x) | `${NOMINAL_RATE}` × 1.5 | < 5000 | < 200ms P99 | < 60% |
| P3 (2x) | `${NOMINAL_RATE}` × 2 | < 10000 | < 500ms P99 | < 70% |
| P4 (2.5x) | `${NOMINAL_RATE}` × 2.5 | < 50000 | < 1000ms P99 | < 80% |
| P5 (3x) | `${NOMINAL_RATE}` × 3 | < 100000 | < 2000ms P99 | < 90% |

**Verdict PERF-02 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | Palier P3 (2x) atteint avec tous critères OK |
| ⚠️ PASS CONDITIONNEL | Palier P2 (1.5x) atteint seulement |
| ❌ FAIL | Palier P2 non atteint |

**Objectif capacité :** Identifier le palier maximal soutenable.

### 3.3 PERF-03 : Charge de Pointe (Burst)

| Critère | Pendant Burst | Après Burst |
|---------|---------------|-------------|
| Throughput | ≥ 80% de `${BURST_RATE}` | Retour à nominal |
| Lag | Augmentation tolérée | Retour à baseline en < `${MAX_CATCHUP_TIME}` min |
| Erreurs | 0 | 0 |
| Messages perdus | 0 | 0 |
| Connecteurs | RUNNING | RUNNING |

**Verdict PERF-03 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | Rattrapage < `${MAX_CATCHUP_TIME}` min, 0 perte |
| ⚠️ PASS CONDITIONNEL | Rattrapage 1-2x cible, 0 perte |
| ❌ FAIL | Perte de données OU rattrapage > 2x cible |

### 3.4 PERF-04 : Endurance

| Checkpoint | Critère Lag | Critère Heap | Critère Erreurs |
|------------|-------------|--------------|-----------------|
| T+1h | Stable ± 10% | Stable ± 5% | 0 |
| T+2h | Stable ± 10% | Stable ± 5% | 0 |
| T+4h | Stable ± 10% | Stable ± 5% | 0 |
| T+8h | Stable ± 10% | Stable ± 5% | 0 |

**Critères spécifiques endurance :**

| Métrique | Seuil PASS | Seuil FAIL |
|----------|------------|------------|
| Drift lag sur 8h | < 1000 records | > 5000 records |
| Memory leak | Pas de tendance croissante | Croissance > 1%/h |
| GC Time augmentation | < 10% | > 50% |
| Restarts MM2 | 0 | > 0 |
| Interruptions | 0 | > 0 |

**Verdict PERF-04 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | 8h sans interruption, métriques stables |
| ⚠️ PASS CONDITIONNEL | 4-8h OK, légère dérive |
| ❌ FAIL | Interruption ou dérive majeure |

### 3.5 PERF-05 : Messages Volumineux

| Taille | Throughput MB/s | Latence P99 | Verdict |
|--------|-----------------|-------------|---------|
| 100 B | ≥ `${TARGET_MBPS}` MB/s | < 500ms | PASS/FAIL |
| 1 KB | ≥ `${TARGET_MBPS}` MB/s | < 500ms | PASS/FAIL |
| 10 KB | ≥ `${TARGET_MBPS}` MB/s | < 1000ms | PASS/FAIL |
| 100 KB | ≥ `${TARGET_MBPS}` MB/s | < 2000ms | PASS/FAIL |
| 1 MB | ≥ 50% `${TARGET_MBPS}` MB/s | < 5000ms | PASS/FAIL |

**Verdict PERF-05 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | Toutes tailles jusqu'à 100KB OK |
| ⚠️ PASS CONDITIONNEL | 1MB dégradé mais fonctionnel |
| ❌ FAIL | Tailles < 100KB non supportées |

### 3.6 PERF-06 : Latence End-to-End

| Percentile | Seuil PASS | Seuil ACCEPTABLE | Seuil FAIL |
|------------|------------|------------------|------------|
| P50 | < 200 ms | 200-500 ms | > 500 ms |
| P95 | < 500 ms | 500-1000 ms | > 1000 ms |
| P99 | < `${MAX_LATENCY_P99_MS}` ms | 1-2x seuil | > 2x seuil |
| P99.9 | < 5000 ms | 5000-10000 ms | > 10000 ms |
| Max | < 10000 ms | 10000-30000 ms | > 30000 ms |

**Verdict PERF-06 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | P99 < seuil, tous autres OK ou acceptables |
| ⚠️ PASS CONDITIONNEL | P99 acceptable, P99.9 ou Max dégradé |
| ❌ FAIL | P99 > seuil |

### 3.7 PERF-07 : Rattrapage de Lag

| Lag Initial | Temps Rattrapage PASS | Temps Rattrapage FAIL |
|-------------|----------------------|----------------------|
| 10,000 records | < 1 min | > 5 min |
| 100,000 records | < 5 min | > 15 min |
| 1,000,000 records | < 30 min | > 60 min |

**Critères supplémentaires :**

| Critère | Seuil PASS | Seuil FAIL |
|---------|------------|------------|
| Messages perdus pendant rattrapage | 0 | > 0 |
| Impact sur production continue | < 10% dégradation | > 20% dégradation |
| Erreurs MM2 | 0 | > 0 |

**Verdict PERF-07 :**

| Résultat | Condition |
|----------|-----------|
| ✅ PASS | Rattrapage dans les temps, 0 perte |
| ⚠️ PASS CONDITIONNEL | Rattrapage 1-2x temps cible, 0 perte |
| ❌ FAIL | Perte de données OU > 2x temps cible |

---

## 4. Matrice de Décision Globale

### 4.1 Pondération des Tests

| Test | Poids | Bloquant |
|------|-------|----------|
| PERF-01 - Nominal | 25% | OUI |
| PERF-02 - Montée en charge | 20% | OUI (P2 min) |
| PERF-03 - Burst | 15% | OUI |
| PERF-04 - Endurance | 15% | NON |
| PERF-05 - Messages volumineux | 5% | NON |
| PERF-06 - Latence | 15% | OUI |
| PERF-07 - Rattrapage | 5% | NON |

### 4.2 Verdict Global

| Score | Verdict | Signification |
|-------|---------|---------------|
| 100% PASS | ✅ VALIDÉ | Prêt pour production |
| > 80% PASS, 0 bloquant FAIL | ⚠️ VALIDÉ SOUS RÉSERVE | Prêt avec recommandations |
| > 60% PASS, 1+ bloquant FAIL | ❌ NON VALIDÉ - REMÉDIATION | Corrections requises |
| ≤ 60% PASS | ❌ NON VALIDÉ - REFONTE | Révision architecture |

---

## 5. Grille de Notation

### 5.1 Fiche de Résultats par Test

```markdown
## Résultat Test: [PERF-XX]

**Date d'exécution:** YYYY-MM-DD HH:MM
**Exécuteur:** [Nom]
**Durée:** XX minutes

### Métriques Mesurées

| Métrique | Valeur Mesurée | Seuil PASS | Seuil FAIL | Verdict |
|----------|----------------|------------|------------|---------|
| ... | ... | ... | ... | ✅/⚠️/❌ |

### Verdict du Test

- [ ] ✅ PASS
- [ ] ⚠️ PASS CONDITIONNEL
- [ ] ❌ FAIL

### Observations

[Notes, anomalies, recommandations]

### Preuves

- Screenshot Grafana: [lien]
- Logs: [chemin]
- Métriques brutes: [chemin CSV]
```

### 5.2 Synthèse Globale

```markdown
## Synthèse Tests de Performance

**Période de test:** Du [DATE] au [DATE]
**Version testée:** MM2 X.X.X / Kafka X.X.X

### Résultats par Test

| Test | Verdict | Score |
|------|---------|-------|
| PERF-01 | ✅/⚠️/❌ | XX% |
| PERF-02 | ✅/⚠️/❌ | XX% |
| PERF-03 | ✅/⚠️/❌ | XX% |
| PERF-04 | ✅/⚠️/❌ | XX% |
| PERF-05 | ✅/⚠️/❌ | XX% |
| PERF-06 | ✅/⚠️/❌ | XX% |
| PERF-07 | ✅/⚠️/❌ | XX% |

### Verdict Global

**Score global:** XX%
**Tests bloquants FAIL:** X
**Verdict:** ✅ VALIDÉ / ⚠️ VALIDÉ SOUS RÉSERVE / ❌ NON VALIDÉ

### Recommandations

1. [Recommandation 1]
2. [Recommandation 2]
3. [Recommandation 3]

### Conformité SLA

| Exigence SLA | Démontré | Preuves |
|--------------|----------|---------|
| Disponibilité 99.9886% | ✅/❌ | [ref] |
| RPO < X sec | ✅/❌ | [ref] |
| RTO < X min | ✅/❌ | [ref] |
```

---

## 6. Procédure de Validation

### 6.1 Étapes de Validation

1. **Exécution complète** - Tous les tests PERF-01 à PERF-07 exécutés
2. **Collecte des preuves** - Logs, screenshots, métriques archivés
3. **Notation** - Chaque test noté selon la grille
4. **Calcul du score global** - Pondération appliquée
5. **Vérification des bloquants** - Aucun test bloquant en FAIL
6. **Rédaction du rapport** - Synthèse et recommandations
7. **Revue technique** - Validation par le Tech Lead
8. **Validation client** - Présentation et accord

### 6.2 Critères de Re-test

| Situation | Action |
|-----------|--------|
| Test FAIL sur erreur d'exécution | Re-test autorisé |
| Test FAIL sur problème infra | Re-test après correction |
| Test FAIL sur limite du système | Pas de re-test, documenter |
| Amélioration apportée | Re-test obligatoire |

---

## 7. Exceptions et Dérogations

### 7.1 Processus de Dérogation

Si un critère ne peut être atteint :

1. Documenter l'écart et l'impact
2. Proposer une mitigation
3. Soumettre à validation client
4. Obtenir accord écrit
5. Mettre à jour le registre des dérogations

### 7.2 Registre des Dérogations

| ID | Critère | Écart | Mitigation | Validé par | Date |
|----|---------|-------|------------|------------|------|
| D-001 | - | - | - | - | - |

---

## Artifacts Produits

- [ ] Fiches de résultats par test
- [ ] Synthèse globale
- [ ] Rapport de conformité SLA
- [ ] Registre des dérogations (si applicable)

---

**Auteur** : `${AUTHOR_NAME}`
**Date de création** : `${DATE_CREATION}`
**Validé par** : `${VALIDATOR_NAME}`
**Version** : 1.0

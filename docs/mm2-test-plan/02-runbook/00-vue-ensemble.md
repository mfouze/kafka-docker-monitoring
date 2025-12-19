# Runbook - Vue d'Ensemble

## Séquence Chronologique

| Phase | Durée | Objectif | Dashboard Principal |
|-------|-------|----------|---------------------|
| **Phase 0** | 1h | Préparation | - |
| **Phase 1** | 15 min | Smoke Test | mm2-replication |
| **Phase 2** | 30 min | Charge Nominale | mm2-replication |
| **Phase 3** | 15 min | Latence E2E | mm2-replication |
| **Phase 4** | 45 min | Montée en Charge | mm2-detailed + Node |
| **Phase 5** | 24h | Long Run | TOUS |
| **Phase 6** | 1h | Résilience | kafka-connect-cluster |
| **Phase 7** | 30 min | Tests Erreurs | mm2-detailed |
| **Phase 8** | 30 min | Validation Prod | - |

**Durée totale (hors long run)** : ~4h30  
**Durée totale (avec long run)** : ~28h

---

## Schéma du Flux de Test

```
                    ┌─────────────────┐
                    │  PRÉPARATION    │
                    │  (Phase 0)      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  SMOKE TEST     │──── Si NOGO ──→ Corriger
                    │  (Phase 1)      │
                    └────────┬────────┘
                             │ GO
                             ▼
                    ┌─────────────────┐
                    │ CHARGE NOMINALE │──── Si NOGO ──→ Optimiser
                    │  (Phase 2)      │
                    └────────┬────────┘
                             │ GO
                             ▼
                    ┌─────────────────┐
                    │  LATENCE E2E    │──── Si NOGO ──→ Tuning
                    │  (Phase 3)      │
                    └────────┬────────┘
                             │ GO
                             ▼
                    ┌─────────────────┐
                    │ MONTÉE CHARGE   │──── Documenter capacité max
                    │  (Phase 4)      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   LONG RUN      │──── Si dégradation ──→ Analyser
                    │  (Phase 5)      │
                    └────────┬────────┘
                             │ Stable
                             ▼
                    ┌─────────────────┐
                    │  RÉSILIENCE     │──── Si NOGO ──→ Corriger HA
                    │  (Phase 6)      │
                    └────────┬────────┘
                             │ GO
                             ▼
                    ┌─────────────────┐
                    │ TESTS ERREURS   │──── Documenter comportements
                    │  (Phase 7)      │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ VALIDATION PROD │
                    │  (Phase 8)      │
                    └────────┬────────┘
                             │
                             ▼
                      ┌──────────────┐
                      │ GO PROD / NOGO│
                      └──────────────┘
```

---

## Fichiers du Runbook

| Fichier | Contenu |
|---------|---------|
| `01-phase0-preparation.md` | Vérifications infrastructure |
| `02-phase1-smoke-test.md` | Validation basique |
| `03-phase2-charge-nominale.md` | Test 1000 msg/s |
| `04-phase3-latence-e2e.md` | Mesure latence avec Grafana |
| `05-phase4-montee-charge.md` | Paliers progressifs |
| `06-phase5-long-run.md` | Test stabilité 24h |
| `07-phase6-resilience.md` | Tests failover |
| `08-phase7-erreurs.md` | Tests de comportement erreur |
| `09-phase8-validation-prod.md` | Checklist finale |

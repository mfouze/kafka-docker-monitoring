# Tunning OS 

```
# Paramètres sysctl recommandés pour Kafka
- name: kafka Prerequisites | Set vm.swappiness to 1
  sysctl:
    name: vm.swappiness
    value: "1"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set vm.dirty_ratio
  sysctl:
    name: vm.dirty_ratio
    value: "80"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set vm.dirty_background_ratio
  sysctl:
    name: vm.dirty_background_ratio
    value: "5"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set net.core.wmem_default
  sysctl:
    name: net.core.wmem_default
    value: "131072"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set net.core.rmem_default
  sysctl:
    name: net.core.rmem_default
    value: "131072"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set net.ipv4.tcp_wmem
  sysctl:
    name: net.ipv4.tcp_wmem
    value: "4096 65536 2048000"
    sysctl_set: yes
    reload: yes
    state: present

- name: kafka Prerequisites | Set net.ipv4.tcp_rmem
  sysctl:
    name: net.ipv4.tcp_rmem
    value: "4096 65536 2048000"
    sysctl_set: yes
    reload: yes
    state: present

```

# Kafka System Tuning Guide

Ce document décrit les paramètres système (sysctl, limits) recommandés pour optimiser les performances de Kafka.

---

## Table des matières

- [1. Paramètres Mémoire](#1-paramètres-mémoire)
  - [vm.swappiness](#vmswappiness)
  - [vm.dirty_ratio](#vmdirty_ratio)
  - [vm.dirty_background_ratio](#vmdirty_background_ratio)
- [2. Paramètres Réseau](#2-paramètres-réseau)
  - [net.core.wmem_default](#netcorewmem_default)
  - [net.core.rmem_default](#netcorermem_default)
  - [net.ipv4.tcp_wmem](#netipv4tcp_wmem)
  - [net.ipv4.tcp_rmem](#netipv4tcp_rmem)
- [3. Limites Système](#3-limites-système)
  - [LimitNOFILE](#limitnofile)
- [4. Configuration Ansible](#4-configuration-ansible)
- [5. Vérification](#5-vérification)

---

## 1. Paramètres Mémoire

### vm.swappiness

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `vm.swappiness` | `1` |

#### Description
Contrôle l'agressivité du kernel Linux à utiliser le swap (mémoire sur disque).

| Valeur | Comportement |
|--------|--------------|
| `0` | N'utilise le swap qu'en cas d'urgence absolue (OOM imminent) |
| `1` | Swap minimal, évite l'OOM killer |
| `60` | Valeur par défaut Linux (trop agressif pour Kafka) |

#### Pourquoi pour Kafka ?
- Kafka utilise **beaucoup de mémoire** pour le cache de pages (page cache)
- Le swap est **~100x plus lent** que la RAM → latence catastrophique
- Si Kafka swappe, les consumers/producers timeoutent
- **Valeur `1`** plutôt que `0` : évite le déclenchement brutal de l'OOM killer

#### Impact
```
Sans tuning (swappiness=60) : Latence variable, pics de latence lors du swap
Avec tuning (swappiness=1)  : Latence stable et prévisible
```

---

### vm.dirty_ratio

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `vm.dirty_ratio` | `80` |

#### Description
Pourcentage **maximum** de mémoire système pouvant contenir des données "dirty" (modifiées, pas encore écrites sur disque) **avant de bloquer les écritures**.

#### Pourquoi 80% pour Kafka ?
- Kafka écrit beaucoup de données séquentiellement sur disque
- Valeur par défaut Linux : `20%` → force des flush trop fréquents
- **80%** permet d'accumuler plus de données en mémoire avant flush
- Le kernel peut optimiser les écritures en batch → **meilleur throughput**

#### Visualisation
```
[Pourcentage mémoire dirty]

0%──────────────20%─────────────────────80%──────100%
                 │                       │
                 │                       └─ Avec tuning: bloque ici
                 └─ Sans tuning: bloque ici (trop tôt!)
```

---

### vm.dirty_background_ratio

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `vm.dirty_background_ratio` | `5` |

#### Description
Pourcentage de mémoire dirty à partir duquel le kernel **commence à écrire en arrière-plan** (sans bloquer les applications).

#### Pourquoi 5% pour Kafka ?
- Valeur par défaut : `10%`
- **5%** = le flush en arrière-plan commence plus tôt
- Évite les pics d'I/O quand on atteint `dirty_ratio`
- **Lissage des écritures** sur le temps

#### Visualisation
```
[Mémoire dirty]

0%────5%────────────────────────────────80%────100%
      │                                  │
      └─ Background flush démarre        └─ Écritures bloquées
         (non-bloquant, progressif)          (bloquant)
```

#### Interaction dirty_ratio / dirty_background_ratio
```
┌────────────────────────────────────────────────────────────┐
│  0%        5%                                    80%  100% │
│  ├─────────┼──────────────────────────────────────┼────┤   │
│            │                                      │        │
│            │  Zone de flush progressif            │        │
│            │  (arrière-plan, non-bloquant)        │        │
│            │                                      │        │
│            └──────────────────────────────────────┘        │
│                                                   │        │
│                                          Bloquant ┘        │
└────────────────────────────────────────────────────────────┘
```

---

## 2. Paramètres Réseau

### net.core.wmem_default

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `net.core.wmem_default` | `131072` (128 KB) |

#### Description
Taille **par défaut** du buffer d'envoi pour toutes les sockets.

#### Pourquoi pour Kafka ?
- Kafka envoie des batches de messages
- Buffer plus grand = moins d'appels système = **meilleur débit**
- Valeur par défaut Linux : ~16 KB (insuffisant pour Kafka)

---

### net.core.rmem_default

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `net.core.rmem_default` | `131072` (128 KB) |

#### Description
Taille **par défaut** du buffer de réception pour toutes les sockets.

#### Pourquoi pour Kafka ?
- Kafka reçoit des batches de messages des producers
- Buffer plus grand = peut recevoir plus de données avant traitement
- Réduit les pertes de paquets sous forte charge

---

### net.ipv4.tcp_wmem

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `net.ipv4.tcp_wmem` | `4096 65536 2048000` |

#### Description
Taille du buffer TCP d'**envoi** avec trois valeurs : `min` `défaut` `max`

| Valeur | Taille | Signification |
|--------|--------|---------------|
| `4096` | 4 KB | Minimum garanti par socket |
| `65536` | 64 KB | Allocation initiale par défaut |
| `2048000` | ~2 MB | Maximum (autotuning peut monter jusque là) |

#### Pourquoi pour Kafka ?
- **Réplication entre brokers** = gros transferts de données
- Maximum élevé permet au kernel d'**adapter dynamiquement** selon le débit
- Améliore le throughput sur les liens haute latence (Bandwidth-Delay Product)
- Essentiel pour les clusters multi-datacenter

---

### net.ipv4.tcp_rmem

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `net.ipv4.tcp_rmem` | `4096 65536 2048000` |

#### Description
Taille du buffer TCP de **réception** avec trois valeurs : `min` `défaut` `max`

| Valeur | Taille | Signification |
|--------|--------|---------------|
| `4096` | 4 KB | Minimum garanti par socket |
| `65536` | 64 KB | Allocation initiale par défaut |
| `2048000` | ~2 MB | Maximum (autotuning peut monter jusque là) |

#### Pourquoi pour Kafka ?
- Permet de **recevoir des bursts** de données sans perte
- Important pour les consumers qui lisent de gros volumes
- Le kernel adapte automatiquement entre 64KB et 2MB selon les besoins

---

## 3. Limites Système

### LimitNOFILE

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| `LimitNOFILE` | `100000` |

#### Description
Nombre maximum de **file descriptors** (fichiers ouverts) par processus.

#### Pourquoi pour Kafka ?
Kafka ouvre énormément de fichiers simultanément :

| Ressource | File descriptors utilisés |
|-----------|---------------------------|
| Segments de log (1 par partition active) | ~1000-5000 |
| Index par segment | ~1000-5000 |
| Connexions clients (producers/consumers) | ~500-2000 |
| Connexions inter-brokers | ~50-100 |
| Connexions ZooKeeper | ~10-50 |
| **Total typique** | **~3000-12000** |

#### Calcul exemple
```
Cluster avec :
- 1000 partitions
- 3 segments actifs par partition
- 500 clients connectés
- 3 brokers

File descriptors = (1000 × 3 × 2) + 500 + (3 × 10) + 50
                 = 6000 + 500 + 30 + 50
                 = 6580 minimum

Valeur 100000 = marge de sécurité confortable
```

#### Erreur sans tuning
```
ERROR org.apache.kafka.common.KafkaException: Too many open files
```

---

## 4. Configuration Ansible

### Fichier : `roles/kafka-prerequisites/tasks/main.yml`

```yaml
# ============================================
# PARAMÈTRES MÉMOIRE
# ============================================

- name: Kafka Prerequisites | Set vm.swappiness to 1
  sysctl:
    name: vm.swappiness
    value: "1"
    sysctl_set: yes
    reload: yes
    state: present

- name: Kafka Prerequisites | Set vm.dirty_ratio to 80
  sysctl:
    name: vm.dirty_ratio
    value: "80"
    sysctl_set: yes
    reload: yes
    state: present

- name: Kafka Prerequisites | Set vm.dirty_background_ratio to 5
  sysctl:
    name: vm.dirty_background_ratio
    value: "5"
    sysctl_set: yes
    reload: yes
    state: present

# ============================================
# PARAMÈTRES RÉSEAU
# ============================================

- name: Kafka Prerequisites | Set net.core.wmem_default
  sysctl:
    name: net.core.wmem_default
    value: "131072"
    sysctl_set: yes
    reload: yes
    state: present

- name: Kafka Prerequisites | Set net.core.rmem_default
  sysctl:
    name: net.core.rmem_default
    value: "131072"
    sysctl_set: yes
    reload: yes
    state: present

- name: Kafka Prerequisites | Set net.ipv4.tcp_wmem
  sysctl:
    name: net.ipv4.tcp_wmem
    value: "4096 65536 2048000"
    sysctl_set: yes
    reload: yes
    state: present

- name: Kafka Prerequisites | Set net.ipv4.tcp_rmem
  sysctl:
    name: net.ipv4.tcp_rmem
    value: "4096 65536 2048000"
    sysctl_set: yes
    reload: yes
    state: present
```

### Fichier : `roles/broker/templates/broker.conf.j2`

```ini
[Service]
LimitNOFILE=100000
```

---

## 5. Vérification

### Vérifier les paramètres sysctl

```bash
# Mémoire
sysctl vm.swappiness
sysctl vm.dirty_ratio
sysctl vm.dirty_background_ratio

# Réseau
sysctl net.core.wmem_default
sysctl net.core.rmem_default
sysctl net.ipv4.tcp_wmem
sysctl net.ipv4.tcp_rmem
```

### Vérifier les limites du processus Kafka

```bash
# Trouver le PID de Kafka
pgrep -f kafka

# Vérifier les limites
cat /proc/<PID>/limits | grep "open files"
```

### Résultat attendu

```
vm.swappiness = 1
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
net.core.wmem_default = 131072
net.core.rmem_default = 131072
net.ipv4.tcp_wmem = 4096	65536	2048000
net.ipv4.tcp_rmem = 4096	65536	2048000

Max open files    100000    100000    files
```

---

## Résumé

```
┌─────────────────────────────────────────────────────────────────┐
│                    KAFKA SYSTEM TUNING                          │
├─────────────────────────────────────────────────────────────────┤
│  MÉMOIRE                                                        │
│  ├── vm.swappiness=1        → Évite le swap (latence)          │
│  ├── vm.dirty_ratio=80      → Max données en RAM avant flush   │
│  └── vm.dirty_background=5  → Flush progressif en arrière-plan │
│                                                                 │
│  RÉSEAU                                                         │
│  ├── wmem/rmem_default=128K → Buffers sockets plus grands      │
│  └── tcp_wmem/rmem=2MB max  → Auto-tuning haute performance    │
│                                                                 │
│  SYSTÈME                                                        │
│  └── LimitNOFILE=100000     → Assez de fichiers pour Kafka     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Références

- [Confluent Documentation - System Requirements](https://docs.confluent.io/platform/current/installation/system-requirements.html)
- [Apache Kafka Documentation - OS Tuning](https://kafka.apache.org/documentation/#os)
- [Linux Kernel Documentation - vm.dirty_ratio](https://www.kernel.org/doc/Documentation/sysctl/vm.txt)
- [Linux Kernel Documentation - TCP tuning](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)

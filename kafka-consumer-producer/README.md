# Scripts Kafka Consumer/Producer pour Tests Prometheus

Ce répertoire contient deux scripts Python permettant de générer une charge de trafic Kafka pour tester et monitorer votre cluster Kafka avec Prometheus.

## 📋 Prérequis

### Dépendances Python

Les scripts nécessitent les bibliothèques suivantes :

```bash
pip install confluent-kafka kafka-python
```

**Note importante** : 
- `kafka_producer_bomber.py` utilise la bibliothèque `kafka-python`
- `kafka_consumer_bomber.py` utilise la bibliothèque `confluent-kafka`

### Configuration Kafka

Les scripts nécessitent :
- Un cluster Kafka avec authentification SASL_SSL/PLAIN
- Des credentials (username/password) valides
- Accès réseau aux brokers Kafka

---

## 🚀 kafka_producer_bomber.py

### Description

Script qui génère et envoie des messages JSON aléatoires vers plusieurs topics Kafka. Il simule différents types de données (activité utilisateur, métriques système, transactions, logs, données de capteurs) pour créer une charge réaliste sur le cluster.

### Utilisation

#### Commande de base

```bash
python3 kafka_producer_bomber.py \
  --bootstrap-servers kafka1:9092,kafka2:9092 \
  --username votre_username \
  --password votre_password
```

#### Options disponibles

| Option | Description | Défaut |
|--------|-------------|--------|
| `--bootstrap-servers` | **Requis.** Liste des serveurs Kafka (séparés par des virgules) | - |
| `--username` | **Requis.** Nom d'utilisateur SASL PLAIN | - |
| `--password` | **Requis.** Mot de passe SASL PLAIN | - |
| `--topic-prefix` | Préfixe des topics à créer | `test-prometheus` |
| `--num-topics` | Nombre de topics à utiliser | `10` |
| `--messages-per-second` | Nombre de messages par seconde à envoyer | `1000` |
| `--num-threads` | Nombre de threads producteurs parallèles | `5` |
| `--duration-minutes` | Durée d'exécution en minutes | `60` |
| `--verbose` | Mode verbeux (logs détaillés) | `False` |

#### Exemples

**Test rapide (5 minutes, 100 msg/s)**
```bash
python3 kafka_producer_bomber.py \
  --bootstrap-servers kafka1:9092 \
  --username admin \
  --password secret \
  --messages-per-second 100 \
  --duration-minutes 5
```

**Test intensif (1 heure, 5000 msg/s, 20 topics)**
```bash
python3 kafka_producer_bomber.py \
  --bootstrap-servers kafka1:9092,kafka2:9092,kafka3:9092 \
  --username admin \
  --password secret \
  --topic-prefix production-test \
  --num-topics 20 \
  --messages-per-second 5000 \
  --num-threads 10 \
  --duration-minutes 60
```

### Types de messages générés

Le script génère 5 types de messages différents :

1. **user_activity** : Activité utilisateur (login, logout, navigation, etc.)
2. **system_metrics** : Métriques système (CPU, mémoire, disque, etc.)
3. **transaction** : Transactions financières
4. **log_event** : Événements de log (DEBUG, INFO, WARN, ERROR, FATAL)
5. **sensor_data** : Données de capteurs IoT (température, humidité, etc.)

### Statistiques affichées

Toutes les 10 secondes, le script affiche :
- Nombre de messages envoyés
- Nombre de messages échoués
- Taux de messages par seconde (msg/s)
- Débit en MB/s
- Nombre de topics utilisés

À la fin de l'exécution, un résumé complet est affiché.

---

## 📥 kafka_consumer_bomber.py

### Description

Script qui consomme des messages JSON depuis plusieurs topics Kafka de manière intensive. Il traite les messages avec une simulation de logique métier pour créer une charge réaliste sur le cluster et mesurer les performances de consommation.

### Utilisation

#### Commande de base

```bash
python3 kafka_consumer_bomber.py \
  --bootstrap-servers kafka1:9092,kafka2:9092 \
  --username votre_username \
  --password votre_password
```

#### Options disponibles

| Option | Description | Défaut |
|--------|-------------|--------|
| `--bootstrap-servers` | **Requis.** Liste des serveurs Kafka (séparés par des virgules) | - |
| `--username` | **Requis.** Nom d'utilisateur SASL PLAIN | - |
| `--password` | **Requis.** Mot de passe SASL PLAIN | - |
| `--topic-prefix` | Préfixe des topics à consommer | `test-prometheus` |
| `--num-topics` | Nombre de topics à consommer | `10` |
| `--consumer-group` | Groupe de consommateurs | `prometheus-test-group` |
| `--num-consumers` | Nombre de consommateurs parallèles | `1` |
| `--duration-minutes` | Durée d'exécution en minutes | `60` |
| `--auto-offset-reset` | Position de départ (`earliest` ou `latest`) | `earliest` |
| `--ssl-cafile` | Chemin vers le fichier CA SSL (optionnel) | - |
| `--ssl-certfile` | Chemin vers le fichier certificat SSL (optionnel) | - |
| `--ssl-keyfile` | Chemin vers le fichier clé SSL (optionnel) | - |
| `--ssl-password` | Mot de passe pour la clé SSL (optionnel) | - |
| `--verbose` | Mode verbeux (logs détaillés) | `False` |

#### Exemples

**Consommation basique**
```bash
python3 kafka_consumer_bomber.py \
  --bootstrap-servers kafka1:9092 \
  --username admin \
  --password secret \
  --duration-minutes 30
```

**Consommation intensive (plusieurs consommateurs)**
```bash
python3 kafka_consumer_bomber.py \
  --bootstrap-servers kafka1:9092,kafka2:9092 \
  --username admin \
  --password secret \
  --topic-prefix production-test \
  --num-topics 20 \
  --consumer-group test-group-1 \
  --num-consumers 3 \
  --duration-minutes 60
```

**Avec certificats SSL personnalisés**
```bash
python3 kafka_consumer_bomber.py \
  --bootstrap-servers kafka1:9092 \
  --username admin \
  --password secret \
  --ssl-cafile /path/to/ca.pem \
  --ssl-certfile /path/to/cert.pem \
  --ssl-keyfile /path/to/key.pem \
  --ssl-password key_password
```

### Traitement des messages

Le script simule un traitement complet des messages :
- **Validation** : Vérifie la structure et le format des messages
- **Transformation** : Normalise et enrichit les données
- **Logique métier** : Traite différemment selon le type de message
- **Délai de traitement** : Simule un temps de traitement réaliste (1-50ms)

### Statistiques affichées

Toutes les 10 secondes, le script affiche :
- Nombre de messages consommés
- Nombre de messages échoués
- Taux de messages par seconde (msg/s)
- Débit en MB/s
- Nombre de messages traités
- Taux d'erreur de traitement
- Topics actifs

À la fin de l'exécution, un résumé détaillé est affiché incluant :
- Statistiques globales
- Répartition par type de message
- Répartition par topic

---

## 🔄 Utilisation combinée

Pour un test complet, vous pouvez lancer les deux scripts simultanément :

**Terminal 1 - Producteur**
```bash
python3 kafka_producer_bomber.py \
  --bootstrap-servers kafka1:9092 \
  --username admin \
  --password secret \
  --messages-per-second 2000 \
  --duration-minutes 60
```

**Terminal 2 - Consommateur**
```bash
python3 kafka_consumer_bomber.py \
  --bootstrap-servers kafka1:9092 \
  --username admin \
  --password secret \
  --num-consumers 2 \
  --duration-minutes 60
```

---

## ⚠️ Notes importantes

### Conflits SSL

Le script `kafka_consumer_bomber.py` peut rencontrer des conflits SSL lors de la création de plusieurs consommateurs simultanément. Par défaut, `--num-consumers` est réglé à `1` pour éviter ces problèmes. Si vous devez utiliser plusieurs consommateurs, augmentez progressivement et surveillez les logs.

### Format des topics

Les scripts créent/consomment des topics au format :
```
{prefix}.generated-data-{num:02d}.json
```

Par exemple, avec le préfixe par défaut `test-prometheus` et 10 topics :
- `test-prometheus.generated-data-01.json`
- `test-prometheus.generated-data-02.json`
- ...
- `test-prometheus.generated-data-10.json`

### Arrêt propre

Les scripts gèrent les signaux `SIGINT` (Ctrl+C) et `SIGTERM` pour un arrêt propre. Ils afficheront les statistiques finales avant de se terminer.

### Performance

Pour des tests de performance optimaux :
- Ajustez `--messages-per-second` selon la capacité de votre cluster
- Utilisez `--num-threads` (producteur) pour paralléliser l'envoi
- Utilisez `--num-consumers` (consommateur) avec précaution (voir note SSL)
- Surveillez les métriques Prometheus pendant l'exécution

---

## 🐛 Dépannage

### Erreur de connexion

Vérifiez :
- Les serveurs Kafka sont accessibles
- Les credentials sont corrects
- Le protocole de sécurité correspond à votre configuration Kafka

### Messages non reçus (consommateur)

Vérifiez :
- Les topics existent et contiennent des messages
- Le `--auto-offset-reset` est correct (`earliest` pour lire depuis le début)
- Le groupe de consommateurs n'est pas déjà utilisé ailleurs

### Performance faible

- Augmentez `--num-threads` pour le producteur
- Vérifiez la charge réseau et CPU
- Surveillez les métriques Kafka (lag, throughput)

---

## 📊 Intégration avec Prometheus

Ces scripts sont conçus pour générer du trafic Kafka qui sera monitoré par Prometheus via les exporters JMX. Les métriques suivantes seront particulièrement intéressantes à surveiller :

- **Producteur** : `kafka_producer_*` (taux d'envoi, latence, erreurs)
- **Consommateur** : `kafka_consumer_*` (lag, throughput, commit rate)
- **Broker** : `kafka_server_*` (bytes in/out, requests, partitions)

Les dashboards Grafana fournis dans ce projet visualisent ces métriques.

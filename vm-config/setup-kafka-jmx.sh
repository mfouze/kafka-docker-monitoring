#!/bin/bash
# Configuration JMX Exporter pour Kafka sur CentOS
# À exécuter sur chaque noeud Kafka

# Variables
JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_PORT="7070"
KAFKA_HOME="${KAFKA_HOME:-/opt/kafka}"
JMX_EXPORTER_DIR="/opt/jmx-exporter"

echo "=== Configuration JMX Exporter pour Kafka ==="

# Créer le répertoire
sudo mkdir -p ${JMX_EXPORTER_DIR}

# Télécharger JMX Exporter
echo "Téléchargement de JMX Exporter..."
sudo curl -L -o ${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar \
    "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

# Copier le fichier de configuration (à copier manuellement)
echo "Copier le fichier kafka-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"

# Configuration KAFKA_OPTS dans le service systemd
echo "
# Ajouter ces lignes dans /etc/systemd/system/kafka.service ou dans kafka-server-start.sh

# Option 1: Via variable d'environnement KAFKA_OPTS
export KAFKA_OPTS=\"-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/kafka-jmx-exporter.yml\"

# Option 2: Dans le fichier de service systemd, ajouter dans [Service]:
# Environment=\"KAFKA_OPTS=-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/kafka-jmx-exporter.yml\"
"

# Ouvrir le port firewall
echo "Ouverture du port ${JMX_EXPORTER_PORT} dans le firewall..."
sudo firewall-cmd --permanent --add-port=${JMX_EXPORTER_PORT}/tcp
sudo firewall-cmd --reload

echo "=== Configuration terminée ==="
echo "N'oubliez pas de:"
echo "1. Copier kafka-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"
echo "2. Redémarrer Kafka: sudo systemctl restart kafka"

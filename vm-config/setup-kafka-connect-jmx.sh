#!/bin/bash
# Configuration JMX Exporter pour Kafka Connect sur CentOS
# À exécuter sur chaque noeud Kafka Connect

# Variables
JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_PORT="7072"
KAFKA_CONNECT_HOME="${KAFKA_CONNECT_HOME:-/opt/kafka}"
JMX_EXPORTER_DIR="/opt/jmx-exporter"

echo "=== Configuration JMX Exporter pour Kafka Connect ==="

# Créer le répertoire
sudo mkdir -p ${JMX_EXPORTER_DIR}

# Télécharger JMX Exporter (si pas déjà fait)
if [ ! -f "${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar" ]; then
    echo "Téléchargement de JMX Exporter..."
    sudo curl -L -o ${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar \
        "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
fi

# Copier le fichier de configuration (à copier manuellement)
echo "Copier le fichier kafka-connect-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"

# Configuration KAFKA_OPTS
echo "
# Ajouter ces lignes dans connect-distributed.sh ou dans le service systemd

# Option 1: Via variable d'environnement KAFKA_OPTS (dans connect-distributed.sh)
export KAFKA_OPTS=\"-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/kafka-connect-jmx-exporter.yml\"

# Option 2: Dans le fichier de service systemd /etc/systemd/system/kafka-connect.service:
# [Service]
# Environment=\"KAFKA_OPTS=-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/kafka-connect-jmx-exporter.yml\"
"

# Ouvrir le port firewall
echo "Ouverture du port ${JMX_EXPORTER_PORT} dans le firewall..."
sudo firewall-cmd --permanent --add-port=${JMX_EXPORTER_PORT}/tcp
sudo firewall-cmd --reload

echo "=== Configuration terminée ==="
echo "N'oubliez pas de:"
echo "1. Copier kafka-connect-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"
echo "2. Redémarrer Kafka Connect: sudo systemctl restart kafka-connect"

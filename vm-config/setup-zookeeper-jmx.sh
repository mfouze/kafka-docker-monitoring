#!/bin/bash
# Configuration JMX Exporter pour Zookeeper sur CentOS
# À exécuter sur chaque noeud Zookeeper

# Variables
JMX_EXPORTER_VERSION="0.20.0"
JMX_EXPORTER_PORT="7071"
ZOOKEEPER_HOME="${ZOOKEEPER_HOME:-/opt/kafka}"
JMX_EXPORTER_DIR="/opt/jmx-exporter"

echo "=== Configuration JMX Exporter pour Zookeeper ==="

# Créer le répertoire
sudo mkdir -p ${JMX_EXPORTER_DIR}

# Télécharger JMX Exporter (si pas déjà fait)
if [ ! -f "${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar" ]; then
    echo "Téléchargement de JMX Exporter..."
    sudo curl -L -o ${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar \
        "https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
fi

# Copier le fichier de configuration (à copier manuellement)
echo "Copier le fichier zookeeper-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"

# Configuration pour Zookeeper
echo "
# Ajouter dans zookeeper-server-start.sh ou dans le service systemd

# Option 1: Via variable d'environnement KAFKA_OPTS (dans zookeeper-server-start.sh)
export KAFKA_OPTS=\"-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/zookeeper-jmx-exporter.yml\"

# Option 2: Pour Zookeeper standalone, utiliser JVMFLAGS dans zkServer.sh ou zkEnv.sh:
# export JVMFLAGS=\"-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/zookeeper-jmx-exporter.yml\"

# Option 3: Dans le fichier de service systemd /etc/systemd/system/zookeeper.service:
# [Service]
# Environment=\"KAFKA_OPTS=-javaagent:${JMX_EXPORTER_DIR}/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:${JMX_EXPORTER_DIR}/zookeeper-jmx-exporter.yml\"
"

# Ouvrir le port firewall
echo "Ouverture du port ${JMX_EXPORTER_PORT} dans le firewall..."
sudo firewall-cmd --permanent --add-port=${JMX_EXPORTER_PORT}/tcp
sudo firewall-cmd --reload

echo "=== Configuration terminée ==="
echo "N'oubliez pas de:"
echo "1. Copier zookeeper-jmx-exporter.yml vers ${JMX_EXPORTER_DIR}/"
echo "2. Redémarrer Zookeeper: sudo systemctl restart zookeeper"

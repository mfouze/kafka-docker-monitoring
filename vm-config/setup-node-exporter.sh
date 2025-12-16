#!/bin/bash
# Installation de Node Exporter sur CentOS
# À exécuter sur TOUTES les VMs (Kafka, Kafka Connect, Zookeeper)

NODE_EXPORTER_VERSION="1.8.1"
NODE_EXPORTER_PORT="9100"

echo "=== Installation de Node Exporter ==="

# Créer l'utilisateur node_exporter
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

# Télécharger Node Exporter
echo "Téléchargement de Node Exporter v${NODE_EXPORTER_VERSION}..."
cd /tmp
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Extraire et installer
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
sudo cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Nettoyer
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64" "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Créer le service systemd
echo "Création du service systemd..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
    --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|host|etc)($$|/)" \\
    --collector.netclass.ignored-devices="^(veth.*|docker.*|br-.*)$$" \\
    --collector.netdev.device-exclude="^(veth.*|docker.*|br-.*)$$" \\
    --web.listen-address=:${NODE_EXPORTER_PORT}

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Recharger systemd et démarrer le service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Ouvrir le port dans le firewall
echo "Ouverture du port ${NODE_EXPORTER_PORT} dans le firewall..."
sudo firewall-cmd --permanent --add-port=${NODE_EXPORTER_PORT}/tcp
sudo firewall-cmd --reload

# Vérifier le statut
echo ""
echo "=== Vérification ==="
sudo systemctl status node_exporter --no-pager

echo ""
echo "=== Test de l'endpoint ==="
curl -s "http://localhost:${NODE_EXPORTER_PORT}/metrics" | head -20

echo ""
echo "=== Installation terminée ==="
echo "Node Exporter écoute sur le port ${NODE_EXPORTER_PORT}"

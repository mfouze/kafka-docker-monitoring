
Jour 3

lancement des 3 connecteurs 
fixe des dash board grafana pour affichage par cluster 
lancement de deux tests dans la foulée 
Test 1

[root@007e98b9b7d3 appuser]# kafka-producer-perf-test \
>   --topic "test-prometheus.generated-data-01.json" \
>   --num-records 1800000 \
>   --record-size 1024 \
>   --throughput 1000 \
>   --producer.config bomberder.properties

5006 records sent, 1000.6 records/sec (0.98 MB/sec), 21.3 ms avg latency, 55.0 ms max latency.
5002 records sent, 999.6 records/sec (0.98 MB/sec), 21.5 ms avg latency, 36.0 ms max latency.
5002 records sent, 1000.4 records/sec (0.98 MB/sec), 21.3 ms avg latency, 36.0 ms max latency.
5004 records sent, 1000.8 records/sec (0.98 MB/sec), 20.8 ms avg latency, 37.0 ms max latency.
4998 records sent, 999.6 records/sec (0.98 MB/sec), 21.3 ms avg latency, 35.0 ms max latency.
5008 records sent, 1001.0 records/sec (0.98 MB/sec), 21.0 ms avg latency, 31.0 ms max latency.
4993 records sent, 998.4 records/sec (0.98 MB/sec), 21.1 ms avg latency, 35.0 ms max latency.
5007 records sent, 1001.2 records/sec (0.98 MB/sec), 21.3 ms avg latency, 34.0 ms max latency.
5005 records sent, 1001.0 records/sec (0.98 MB/sec), 21.0 ms avg latency, 32.0 ms max latency.
4993 records sent, 998.6 records/sec (0.98 MB/sec), 20.8 ms avg latency, 34.0 ms max latency.
5006 records sent, 1001.2 records/sec (0.98 MB/sec), 21.0 ms avg latency, 36.0 ms max latency.
4996 records sent, 999.2 records/sec (0.98 MB/sec), 21.3 ms avg latency, 36.0 ms max latency.
4999 records sent, 999.0 records/sec (0.98 MB/sec), 22.4 ms avg latency, 71.0 ms max latency.
5003 records sent, 1000.6 records/sec (0.98 MB/sec), 21.2 ms avg latency, 39.0 ms max latency.
5004 records sent, 1000.6 records/sec (0.98 MB/sec), 21.0 ms avg latency, 36.0 ms max latency.
4994 records sent, 998.8 records/sec (0.98 MB/sec), 21.1 ms avg latency, 37.0 ms max latency.
5007 records sent, 1001.4 records/sec (0.98 MB/sec), 20.9 ms avg latency, 36.0 ms max latency.
5002 records sent, 999.8 records/sec (0.98 MB/sec), 20.9 ms avg latency, 33.0 ms max latency.
5006 records sent, 1001.0 records/sec (0.98 MB/sec), 21.0 ms avg latency, 35.0 ms max latency.
4998 records sent, 999.6 records/sec (0.98 MB/sec), 21.4 ms avg latency, 33.0 ms max latency.
5001 records sent, 1000.2 records/sec (0.98 MB/sec), 21.3 ms avg latency, 36.0 ms max latency.
4999 records sent, 999.8 records/sec (0.98 MB/sec), 21.3 ms avg latency, 35.0 ms max latency.
5008 records sent, 1001.6 records/sec (0.98 MB/sec), 21.2 ms avg latency, 35.0 ms max latency.
4996 records sent, 999.0 records/sec (0.98 MB/sec), 21.1 ms avg latency, 34.0 ms max latency.
4999 records sent, 999.8 records/sec (0.98 MB/sec), 22.2 ms avg latency, 87.0 ms max latency.
1800000 records sent, 999.982223 records/sec (0.98 MB/sec), 21.41 ms avg latency, 889.00 ms max latency, 23 ms 50th, 28 ms 95th, 32 ms 99th, 63 ms 99.9th.

Test 2

[root@007e98b9b7d3 appuser]# kafka-producer-perf-test   --topic "test-prometheus.generated-data-01.json"   --num-records 1800000   --record-size 1024   --throughput -1   --producer.config bomberder.properties
Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/pki/tls/certs/kafka-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=jks
39496 records sent, 7899.2 records/sec (7.71 MB/sec), 1964.8 ms avg latency, 4102.0 ms max latency.
46710 records sent, 9340.1 records/sec (9.12 MB/sec), 3303.4 ms avg latency, 4244.0 ms max latency.
44880 records sent, 8974.2 records/sec (8.76 MB/sec), 3411.7 ms avg latency, 4309.0 ms max latency.
46830 records sent, 9364.1 records/sec (9.14 MB/sec), 3296.4 ms avg latency, 4283.0 ms max latency.
47085 records sent, 9415.1 records/sec (9.19 MB/sec), 3279.3 ms avg latency, 4259.0 ms max latency.
46620 records sent, 9322.1 records/sec (9.10 MB/sec), 3277.9 ms avg latency, 4205.0 ms max latency.
46590 records sent, 9314.3 records/sec (9.10 MB/sec), 3297.1 ms avg latency, 4251.0 ms max latency.
46875 records sent, 9369.4 records/sec (9.15 MB/sec), 3293.1 ms avg latency, 4255.0 ms max latency.
47145 records sent, 9429.0 records/sec (9.21 MB/sec), 3270.2 ms avg latency, 4171.0 ms max latency.
46950 records sent, 9384.4 records/sec (9.16 MB/sec), 3264.8 ms avg latency, 4178.0 ms max latency.
47190 records sent, 9434.2 records/sec (9.21 MB/sec), 3264.8 ms avg latency, 4139.0 ms max latency.
47295 records sent, 9455.2 records/sec (9.23 MB/sec), 3240.2 ms avg latency, 4095.0 ms max latency.
46875 records sent, 9375.0 records/sec (9.16 MB/sec), 3275.0 ms avg latency, 4183.0 ms max latency.
46875 records sent, 9373.1 records/sec (9.15 MB/sec), 3280.9 ms avg latency, 4218.0 ms max latency.
46200 records sent, 9238.2 records/sec (9.02 MB/sec), 3332.3 ms avg latency, 4196.0 ms max latency.
47235 records sent, 9447.0 records/sec (9.23 MB/sec), 3248.2 ms avg latency, 4109.0 ms max latency.
47025 records sent, 9405.0 records/sec (9.18 MB/sec), 3269.8 ms avg latency, 4139.0 ms max latency.
47355 records sent, 9471.0 records/sec (9.25 MB/sec), 3249.4 ms avg latency, 4103.0 ms max latency.
46620 records sent, 9322.1 records/sec (9.10 MB/sec), 3279.3 ms avg latency, 4101.0 ms max latency.
46995 records sent, 9397.1 records/sec (9.18 MB/sec), 3281.7 ms avg latency, 4184.0 ms max latency.
47010 records sent, 9400.1 records/sec (9.18 MB/sec), 3270.1 ms avg latency, 4136.0 ms max latency.
47325 records sent, 9461.2 records/sec (9.24 MB/sec), 3242.7 ms avg latency, 4087.0 ms max latency.
47040 records sent, 9406.1 records/sec (9.19 MB/sec), 3274.4 ms avg latency, 4084.0 ms max latency.
47385 records sent, 9477.0 records/sec (9.25 MB/sec), 3248.5 ms avg latency, 4151.0 ms max latency.
47190 records sent, 9438.0 records/sec (9.22 MB/sec), 3241.5 ms avg latency, 4102.0 ms max latency.
46785 records sent, 9353.3 records/sec (9.13 MB/sec), 3280.8 ms avg latency, 4138.0 ms max latency.
45900 records sent, 9180.0 records/sec (8.96 MB/sec), 3363.8 ms avg latency, 4218.0 ms max latency.
47370 records sent, 9472.1 records/sec (9.25 MB/sec), 3238.3 ms avg latency, 4110.0 ms max latency.
46815 records sent, 9359.3 records/sec (9.14 MB/sec), 3285.5 ms avg latency, 4132.0 ms max latency.
47325 records sent, 9465.0 records/sec (9.24 MB/sec), 3251.6 ms avg latency, 4095.0 ms max latency.
46455 records sent, 9291.0 records/sec (9.07 MB/sec), 3302.2 ms avg latency, 4068.0 ms max latency.
47595 records sent, 9519.0 records/sec (9.30 MB/sec), 3233.4 ms avg latency, 4078.0 ms max latency.
47145 records sent, 9427.1 records/sec (9.21 MB/sec), 3261.2 ms avg latency, 4212.0 ms max latency.
47040 records sent, 9404.2 records/sec (9.18 MB/sec), 3243.6 ms avg latency, 4139.0 ms max latency.
47400 records sent, 9480.0 records/sec (9.26 MB/sec), 3275.0 ms avg latency, 4181.0 ms max latency.
47250 records sent, 9450.0 records/sec (9.23 MB/sec), 3239.1 ms avg latency, 4027.0 ms max latency.
47190 records sent, 9436.1 records/sec (9.21 MB/sec), 3252.0 ms avg latency, 4041.0 ms max latency.
47355 records sent, 9467.2 records/sec (9.25 MB/sec), 3251.2 ms avg latency, 4100.0 ms max latency.
1800000 records sent, 9308.483131 records/sec (9.09 MB/sec), 3247.29 ms avg latency, 4309.00 ms max latency, 3000 ms 50th, 4160 ms 95th, 4236 ms 99th, 4286 ms 99.9th.
[root@007e98b9b7d3 appuser]#
 

Remarque : 
- Forte latences lors de la production des données 
- Latence zookeeper en moyenne de 80 ms 
- throughput correct sur l'entree des messages 
- Sur le test 1 le fait de caper le thoughput ameliore la latence 
- La cpu des brokers utiiséée a 25%


- Application des optimisations au niveau des brokers 

```

# -----------------------------------------------------------------------------
# THREADS - ADAPTÉ 4 vCPU
# -----------------------------------------------------------------------------
# Threads réseau (recommandé: num_cpus)
num.network.threads=4

# Threads I/O (recommandé: 2 * num_cpus)
num.io.threads=8

# Threads réplication (améliore catch-up)
num.replica.fetchers=2

# Threads recovery (accélère restart)
num.recovery.threads.per.data.dir=2

# -----------------------------------------------------------------------------
# RÉPLICATION ET DURABILITÉ
# -----------------------------------------------------------------------------
# Facteur de réplication par défaut
default.replication.factor=3

# ISR minimum pour les writes
min.insync.replicas=2

# Réplication factor topics internes
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

# Unclean leader election (DÉSACTIVÉ pour durabilité)
unclean.leader.election.enable=false

# Auto-création topics (Activé pour les tests)
auto.create.topics.enable=true


# -----------------------------------------------------------------------------
# BUFFER ET MÉMOIRE SOCKET
# -----------------------------------------------------------------------------
# Buffer socket (1 MB - adapté réseau interne)
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576

# Taille max requête (100 MB)
socket.request.max.bytes=104857600

# Réplication buffer
replica.socket.receive.buffer.bytes=1048576
replica.fetch.max.bytes=10485760

```

```

# -----------------------------------------------------------------------------
# ZOOKEEPER
# -----------------------------------------------------------------------------
zookeeper.connect=${ZK_CONNECT}
# Exemple: zookeeper.connect=zk1:2181,zk2:2181,zk3:2181/kafka

zookeeper.connection.timeout.ms=18000
zookeeper.session.timeout.ms=18000


```
Reflexion axes d'amelioration 
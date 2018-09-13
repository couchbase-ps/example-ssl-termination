set -m

### DEFAULTS
NODE_TYPE=${NODE_TYPE:='DEFAULT'}
CLUSTER_USERNAME=${CLUSTER_USERNAME:='Administrator'}
CLUSTER_PASSWORD=${CLUSTER_PASSWORD:='password'}
CLUSTER_RAMSIZE=${CLUSTER_RAMSIZE:=300}
SERVICES=${SERVICES:='data,index,query,fts,eventing'}
BUCKET=${BUCKET:='default'}
BUCKET_RAMSIZE=${BUCKET_RAMSIZE:=100}
BUCKET_TYPE=${BUCKET_TYPE:=couchbase}
RBAC_USERNAME=${RBAC_USERNAME:=$BUCKET}
RBAC_PASSWORD=${RBAC_PASSWORD:=$CLUSTER_PASSWORD}
RBAC_ROLES=${RBAC_ROLES:='admin'}
SAMPLE_BUCKETS=${SAMPLE_BUCKETS:='travel-sample'}

sleep 2
echo ' '

printf 'Waiting for Couchbase Server to start'
until $(curl --output /dev/null --silent --head --fail -u $CLUSTER_USERNAME:$CLUSTER_PASSWORD http://localhost:8091/pools); do
  printf .
  sleep 1
done

echo ' '
echo Couchbase Server has started
echo Starting configuration

# configure individual node settings
echo Configuring Node Settings
/opt/couchbase/bin/couchbase-cli node-init \
  --cluster localhost:8091 \
  --user=$CLUSTER_USERNAME \
  --password=$CLUSTER_PASSWORD \
  --node-init-data-path=${NODE_INIT_DATA_PATH:='/opt/couchbase/var/lib/couchbase/data'} \
  --node-init-index-path=${NODE_INIT_INDEX_PATH:='/opt/couchbase/var/lib/couchbase/indexes'} \
  --node-init-hostname=${NODE_INIT_HOSTNAME:='127.0.0.1'} \
> /dev/null

# configure the cluster
echo Configuring Cluster
CMD="/opt/couchbase/bin/couchbase-cli cluster-init"
CMD="$CMD --cluster localhost:8091"
CMD="$CMD --cluster-username $CLUSTER_USERNAME"
CMD="$CMD --cluster-password $CLUSTER_PASSWORD"
CMD="$CMD --cluster-ramsize $CLUSTER_RAMSIZE"
# is the index service going to be running?
if [[ $SERVICES == *"index"* ]]; then
  CMD="$CMD --index-storage-setting ${INDEX_STORAGE_SETTING:=default}"
  CMD="$CMD --cluster-index-ramsize ${CLUSTER_INDEX_RAMSIZE:=256}"
fi
# is the fts service going to be running?
if [[ $SERVICES == *"fts"* ]]; then
  CMD="$CMD --cluster-fts-ramsize ${CLUSTER_FTS_RAMSIZE:=256}"
fi
# is the eventing service going to be running?
if [[ $SERVICES == *"eventing"* ]]; then
  CMD="$CMD --cluster-eventing-ramsize ${CLUSTER_EVENTING_RAMSIZE:=256}"
fi
# is the analytics service going to be running?
if [[ $SERVICES == *"analytics"* ]]; then
  CMD="$CMD --cluster-analytics-ramsize ${CLUSTER_ANALYTICS_RAMSIZE:=1024}"
fi
CMD="$CMD --services=$SERVICES"
CMD="$CMD > /dev/null"
eval $CMD

echo Setting the Cluster Name
/opt/couchbase/bin/couchbase-cli setting-cluster \
  --cluster localhost:8091 \
  --user $CLUSTER_USERNAME \
  --password $CLUSTER_PASSWORD \
  --cluster-name "$(echo $CLUSTER_NAME)" \
> /dev/null

# create a bucket
echo Creating $BUCKET bucket
/opt/couchbase/bin/couchbase-cli bucket-create \
  --cluster localhost:8091 \
  --username $CLUSTER_USERNAME \
  --password $CLUSTER_PASSWORD \
  --bucket $BUCKET \
  --bucket-ramsize $BUCKET_RAMSIZE \
  --bucket-type $BUCKET_TYPE \
  --bucket-priority ${BUCKET_PRIORITY:=low} \
  --enable-index-replica ${ENABLE_INDEX_REPLICA:=0} \
  --enable-flush ${ENABLE_FLUSH:=0} \
  --bucket-replica ${BUCKET_REPLICA:=1} \
  --bucket-eviction-policy ${BUCKET_EVICTION_POLICY:=valueOnly} \
  --compression-mode ${BUCKET_COMPRESSION:=off} \
  --max-ttl ${BUCKET_MAX_TTL:=0} \
  --wait \
> /dev/null

# rbac user
echo Creating RBAC user $RBAC_USERNAME
/opt/couchbase/bin/couchbase-cli user-manage \
  --cluster localhost:8091 \
  --username $CLUSTER_USERNAME \
  --password $CLUSTER_PASSWORD \
  --set \
  --rbac-username $RBAC_USERNAME \
  --rbac-password $RBAC_PASSWORD \
  --roles $RBAC_ROLES \
  --auth-domain local \
> /dev/null

# load sample buckets
if [ -n "$SAMPLE_BUCKETS" ]; then
  # loop over the comma-delimited list of sample buckets i.e. beer-sample,travel-sample
  for SAMPLE in $(echo $SAMPLE_BUCKETS | sed "s/,/ /g")
  do
    # make sure the sample requested actually exists
    if [ -e /opt/couchbase/samples/$SAMPLE.zip ]; then
      # load the sample documents into the bucket
      echo Loading $SAMPLE bucket
      /opt/couchbase/bin/cbdocloader \
        -n localhost:8091 \
        -u $CLUSTER_USERNAME \
        -p $CLUSTER_PASSWORD \
        -b $SAMPLE \
        -s 100 \
        /opt/couchbase/samples/$SAMPLE.zip \
      > /dev/null 2>&1
    else
      echo Skipping... the $SAMPLE is not available
    fi
  done
fi

# configure alternate addresses
echo 'Configuring alternate addresses'
curl -X PUT -s \
  -u "$CLUSTER_USERNAME:$CLUSTER_PASSWORD" \
  -d "hostname=${NODE_INIT_HOSTNAME:='127.0.0.1'}&mgmtSSL=28091&capiSSL=28092&n1qlSSL=28093&ftsSSL=28094&kvSSL=21207&kv=21210" \
  http://localhost:8091/node/controller/setupAlternateAddresses/external

# Nginx will fail initially to start because it relies on the Couchbase certificates to
# be available, and those are not created until the cluster is configured
echo 'Starting nginx'
service nginx start > /dev/null

echo The node has been successfully configured
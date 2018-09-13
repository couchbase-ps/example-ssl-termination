# SSL Termination Example

This example illustrates SSL termination with Couchbase using alternate addresses.   NOTE: Requires Couchbase Server 5.5+ and latest [2.6.0+ build of Java SDK](https://docs.couchbase.com/java-sdk/2.6/start-using-sdk.html).

--

## Getting Started 

This demo can be setup with docker or manually, instructions for both are provided below.  

**Clone the Repository**

```bash
git clone https://github.com/couchbase-ps/example-ssl-termination.git
```

## Docker Setup

**Start the Container**

```bash
docker-compose up -d --build
```

Once the container has been started, it will automatically configure itself as a single node cluster and load the `travel-sample` bucket.  This takes a 15-30 seconds to complete, running the following command will verify the setup is complete: 

**Monitor startup statush**

```bash
docker logs couchbase

Starting Couchbase Server -- Web UI available at http://<ip>:8091
and logs available in /opt/couchbase/var/lib/couchbase/logs

Waiting for Couchbase Server to start........
Couchbase Server has started
Starting configuration
Configuring Node Settings
Configuring Cluster
Setting the Cluster Name
Creating demo bucket
Creating RBAC user demo
Loading travel-sample bucket
Configuring alternate addresses
Starting nginx
The node has been successfully configured
```

## Manual Setup

1\. Install Couchbase Server

2\. Once Couchbase Server is started and configured, run the following command: 

```bash
curl -X PUT \
	-u Administrator:password \
	-d 'hostname=127.0.0.1' \
	-d 'mgmtSSL=28091' \
	-d 'capiSSL=28092' \
	-d 'n1qlSSL=28093' \
	-d 'ftsSSL=28094' \
	-d 'kvSSL=21207' \
	-d 'kv=21210' \
	http://127.0.0.1:8091/node/controller/setupAlternateAddresses/external
```

3\. Copy the [.docker/couchbase/nginx/nginx.conf](.docker/couchbase/nginx/nginx.conf) file into the appropriate location (usually `/etc/nginx/nginx.conf`).  **Note:** You may need to edit this file to ensure the appropriate user and permissions. 

4\. Restart nginx (On Ubuntu 16.04 `service nginx restart`

---

## Client SSL Configuration

Once Couchbase Server and Nginx have been configured and are running, the client will need to be configured with the certificate.

[Documentation](https://docs.couchbase.com/java-sdk/2.6/managing-connections.html#ssl)

If using docker, you can execute the following command, which will execute the [couchbase-cli](https://docs.couchbase.com/server/5.5/cli/cbcli/couchbase-cli-ssl-manage.html) command to retrieve the cluster certificate and output it to a file named `example-ssl-termination.cert`

```bash
docker exec couchbase \
	/opt/couchbase/bin/couchbase-cli ssl-manage \
	--cluster localhost \
	--username Administrator \
	--password password \
	--cluster-cert-info \
> example-ssl-termination.cert
```

The certificate can also be retrieved manually by logging in to the [Admin UI](http://localhost:8091) -> [Security](http://localhost:8091/ui/index.html#!/security) -> [Root Certificate](http://localhost:8091/ui/index.html#!/security/rootCertificate).

Now use the `keytool` command to import the certificate into the JVM keystore. 

```bash
keytool \
	-importcert \
	-file example-ssl-termination.cert \
	-alias example-ssl-termination \
	-keystore ~/.keystore \
	-storepass password \
	-keypass password \
	-noprompt
```

**Note:** Rebuilding a new container, making changes, etc. will configure a new cluster, which in turn will generate a new certificate.  If you get the error "keytool error: java.lang.Exception: Certificate not imported, alias <example-ssl-termination> already exists".  You can remove it using the following command: 

```bash
keytool -delete \
	-alias example-ssl-termination \
	-keystore ~/.keystore \
	-storepass password \
	-noprompt
```

---

## Run

Run the `Test.java` application and view the logs.  By default the sample application has the finest level of logging turned on.  It will connect to the cluster, retrieve 1 document via the `get()` method and another document via a N1QL select statement.

You will need to edit the application to point to the appropriate keystore.

package example;
import com.couchbase.client.java.Bucket;
import com.couchbase.client.java.Cluster;
import com.couchbase.client.java.CouchbaseCluster;
import com.couchbase.client.java.document.JsonDocument;
import com.couchbase.client.java.query.N1qlQuery;
import com.couchbase.client.java.query.N1qlQueryResult;
import com.couchbase.client.java.env.CouchbaseEnvironment;
import com.couchbase.client.java.env.DefaultCouchbaseEnvironment;
import com.couchbase.client.core.env.NetworkResolution;

import java.util.logging.Logger;
import java.util.logging.ConsoleHandler;
import java.util.logging.Handler;
import java.util.logging.Level;

public class Test {

	public static void main(String[] args) {
		Test obj = new Test();
		obj.run();
	}

	public void run() {

		Logger logger = Logger.getLogger("com.couchbase.client");
		logger.setLevel(Level.FINEST);
		for(Handler h : logger.getParent().getHandlers()) {
			if(h instanceof ConsoleHandler){
				h.setLevel(Level.FINEST);
			}
		}

		CouchbaseEnvironment environment = DefaultCouchbaseEnvironment
			.builder()
			.bootstrapCarrierSslPort(21207)
			.sslEnabled(true)
			.sslKeystoreFile("/Users/aaronbenton/.keystore")
			.sslKeystorePassword("password")	
			.networkResolution(NetworkResolution.EXTERNAL)
			.build();

		Cluster cluster = CouchbaseCluster.create(environment, "localhost");
		cluster.authenticate("demo", "password");
		Bucket bucket = cluster.openBucket("travel-sample");

		JsonDocument doc = bucket.get("airline_10");
		System.out.println("");
		System.out.println("");
		System.out.println("Document: airline_10");
		System.out.println(doc.content());
		System.out.println("");
		System.out.println("");

		N1qlQuery query = N1qlQuery.simple("select * from `travel-sample` use keys ['airport_1254']");
		N1qlQueryResult result = bucket.query(query);
		System.out.println("");
		System.out.println("");
		System.out.println("Query Results:");
		System.out.println(result.toString());
		System.out.println("");
		System.out.println("");

		System.out.println("Disconnecting");
		bucket.close();
		cluster.disconnect();

	}
}

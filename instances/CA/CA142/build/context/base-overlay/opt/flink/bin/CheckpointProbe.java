import com.amazonaws.ClientConfiguration;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.client.builder.AwsClientBuilder;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class CheckpointProbe {
    private static final long DELAY_MILLIS = 800;
    private static final int DEFAULT_TIMEOUT_MILLIS = 250;
    private static final Pattern OPTION = Pattern.compile("^([A-Za-z0-9_.-]+):\\s*([0-9]+)\\s*$");

    private CheckpointProbe() {}

    private static int configuredTimeoutMillis() throws IOException {
        Map<String, Integer> values = new HashMap<>();
        for (String line : Files.readAllLines(Path.of("/etc/flink/flink-conf.yaml"))) {
            Matcher matcher = OPTION.matcher(line);
            if (matcher.matches()) {
                values.put(matcher.group(1), Integer.valueOf(matcher.group(2)));
            }
        }
        int timeout = DEFAULT_TIMEOUT_MILLIS;
        for (String key : new String[] {"s3.connect-timeout", "s3.socket-timeout"}) {
            if (values.containsKey(key)) {
                timeout = Math.min(timeout == DEFAULT_TIMEOUT_MILLIS ? Integer.MAX_VALUE : timeout, values.get(key));
            }
        }
        return timeout == Integer.MAX_VALUE ? DEFAULT_TIMEOUT_MILLIS : timeout;
    }

    private static final class DelayedObjectHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            exchange.getRequestBody().readAllBytes();
            try {
                Thread.sleep(DELAY_MILLIS);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
            }
            byte[] response = new byte[0];
            exchange.getResponseHeaders().add("ETag", "\"checkpoint-object\"");
            exchange.sendResponseHeaders(200, response.length);
            try (OutputStream output = exchange.getResponseBody()) {
                output.write(response);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        int timeoutMillis = configuredTimeoutMillis();
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/checkpoint-bucket/checkpoint-object", new DelayedObjectHandler());
        server.start();
        AmazonS3 client = null;
        try {
            ClientConfiguration configuration = new ClientConfiguration()
                    .withConnectionTimeout(timeoutMillis)
                    .withSocketTimeout(timeoutMillis)
                    .withMaxErrorRetry(0);
            client = AmazonS3ClientBuilder.standard()
                    .withClientConfiguration(configuration)
                    .withEndpointConfiguration(new AwsClientBuilder.EndpointConfiguration(
                            "http://127.0.0.1:" + server.getAddress().getPort(), "us-east-1"))
                    .withPathStyleAccessEnabled(true)
                    .withCredentials(new AWSStaticCredentialsProvider(
                            new BasicAWSCredentials("access-key", "secret-key")))
                    .build();
            byte[] checkpoint = "checkpoint-object".getBytes(StandardCharsets.UTF_8);
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.setContentLength(checkpoint.length);
            client.putObject(new PutObjectRequest(
                    "checkpoint-bucket", "checkpoint-object",
                    new ByteArrayInputStream(checkpoint), metadata));
            System.out.println("[checkpoint-probe] checkpoint upload completed");
        } catch (Exception failure) {
            System.err.println("[checkpoint-probe] S3 read timed out");
            System.err.println("[checkpoint-probe] effective read timeout: " + timeoutMillis + "ms (" + failure.getMessage() + ")");
            System.exit(42);
        } finally {
            if (client != null) {
                client.shutdown();
            }
            server.stop(0);
        }
    }
}

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LogBurst {
    private static final Logger LOG = LoggerFactory.getLogger(LogBurst.class);
    public static void main(String[] args) throws Exception {
        int count = args.length == 0 ? 1 : Integer.parseInt(args[0]);
        for (int i = 0; i < count; i++) {
            LOG.info("vehicle event {} {}", i, "0123456789012345678901234567890123456789");
        }
        Thread.sleep(300);
    }
}

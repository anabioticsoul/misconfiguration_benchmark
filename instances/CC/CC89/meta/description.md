# Hadoop MapReduce job does not produce any logs and stats in local mode

# Question

I am writing very basic map reduce job to count words in a text file in local mode. Though job is running fine and gives output but it does not produce any map reduce logs or statistics.

I have configured log4j.properties file as well in my project but that also does not work.

When I write logs statements in my own program, those log statements are logged without any issue. I have tried multiple options mentioned on web like setting env variable HADOOP\_ROOT\_LOGGER, passing it to program with log level but nothing works.

I am using hadoop 3.2.4. I have tried from both command line as well as from with in IDE but no logs are generated.

Here is my log4j.properties file

```
# Set root logger level to INFO and its only appender to A1.
log4j.rootLogger=INFO, A1

# A1 is set to be a ConsoleAppender.
log4j.appender.A1=org.apache.log4j.ConsoleAppender

# A1 uses PatternLayout.
log4j.appender.A1.layout=org.apache.log4j.PatternLayout
log4j.appender.A1.layout.ConversionPattern=%-4r [%t] %-5p %c %x - %m%n

log4j.logger.org.apache.hadoop=INFO, A1
log4j.logger.rg.apache.hadoop.mapreduce=DEBUG, A1
```

Here is my main class code which triggers the job:

```
public static void main(String[] args) throws Exception {

    Configuration conf = new Configuration();

    Job job = Job.getInstance(conf, "Word Count");
    logger.info("Running word count...");

    FileSystem fs = FileSystem.get(new Configuration());
    // true stands for recursively deleting the folder you gave
    logger.info("Cleaning output directory...");
    fs.delete(new Path(OUTPUT_PATH), true);

    job.setMapperClass(WordCountMapper.class);
    job.setReducerClass(WordCountReducer.class);
    job.setJarByClass(WordCountMain.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);

    FileInputFormat.addInputPath(job, new Path(INPUT_PATH));
    FileOutputFormat.setOutputPath(job, new Path(OUTPUT_PATH));

    boolean success = job.waitForCompletion(true);

    logger.info("Job status : " + (success ? "Passed" : "Failed"));
    System.exit(0);
}
```



### Question Comments

=== COMMENTS ===
- (1) OneCricketeer [Commented Apr 25, 2023 at 13:01]: Typo? log4j.logger.rg . Also please share what logs it does produce.. Is the input path empty, so therefore no statistics should be printed?
- (2) unknown: 
- (3) Bagira [Commented Apr 25, 2023 at 13:49]: Thanks for pointing out the typo. Correcting that does not help. Input path is not empty. I can see the output.  Logs only show the log statements which I have added. Refer the java code above for log statements.
- (4) OneCricketeer [Commented Apr 25, 2023 at 13:51]: The code above doesn't show any mapreduce framework logs. Please edit to include the logs you see in YARN and clarify what output you're expecting to get
- (5) unknown: 


---


# Accepted Answer

I managed to solve the problem. Posting here in case someone else lands up in same situation. Adding slf4j-simple jar in pom.xml solved the issue for me.

```
    <dependency>
        <groupId>org.slf4j</groupId>
        <artifactId>slf4j-simple</artifactId>
        <version>1.6.2</version>
    </dependency>
```
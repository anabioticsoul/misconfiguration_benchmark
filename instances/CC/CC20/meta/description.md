# Cannot initialize Cluster. Please check your configuration for mapreduce.framework.name and the correspond server addresses-submiting job2remoteClustr

# Question

I recently upgraded my cluster from Apache Hadoop1.0 to CDH4.4.0. I have a weblogic server in another machine from where i submit jobs to this remote cluster via mapreduce client. I still want to use MR1 and not Yarn. I have compiled my client code against the client jars in the CDH installtion (/usr/lib/hadoop/client/\*)

Am getting the below error when creating a JobClient instance. **There are many posts related to the same issue but all the solutions refer to the scenario of submitting the job to a local cluster and not to remote and specifically in my case from a wls container**.

`JobClient jc = new JobClient(conf);`

`Cannot initialize Cluster. Please check your configuration for mapreduce.framework.name and the correspond server addresses.`

But running from the command prompt on the cluster works perfectly fine.

Appreciate your timely help!


---


# Accepted Answer

It's likely that your app is looking at your old Hadoop 1.x configuration files. Maybe your app hard-codes some config? This error tends to indicate you are using the new client libraries but that they are not seeing new-style configuration.

It must exist since the command-line tools see them fine. Check your `HADOOP_HOME` or `HADOOP_CONF_DIR` env variables too although that's what the command line tools tend to pick up, and they work.

Note that you need to install the 'mapreduce' service and not 'yarn' in CDH 4.4 to make it compatible with MR1 clients. See also the '...-mr1-...' artifacts in Maven.
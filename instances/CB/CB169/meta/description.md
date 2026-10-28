# Vagrant - How to access guests postgres server from host

# Question

I have a vagrant box installed with a postgres server running on it on port `5432`, and I added this to the `Vagrantfile`:

```
  config.vm.network "private_network", ip: "192.168.33.33"
  config.vm.network "forwarded_port", guest: 5432, host: 3333
```

But when I try to connect to the postgres server by connecting to `192.168.33.33:3333`

I get this error:

[![enter image description here](images/CB169/e0Pgv.png)](https://i.sstatic.net/e0Pgv.png)

Connection refused, this is the same error I'll get if I try to connect to any ports that aren't open. I ran a port scanner on 192.168.33.33 and didn't see any of the forwarded ports open. This is actually what I have in the Vagrantfile:

```
  config.vm.network "forwarded_port", guest: 8000, host: 8001
  config.vm.network "forwarded_port", guest: 3333, host: 3334
  config.vm.network "forwarded_port", guest: 5555, host: 5556
  config.vm.network "forwarded_port", guest: 5432, host: 3333

  config.vm.network "forwarded_port", guest: 80, host: 8888,
    auto_correct: true
```

and heres the results from the port scanner:

[![enter image description here](images/CB169/aejrh.png)](https://i.sstatic.net/aejrh.png)

It didn't detect any ports above 995. How do I access the VMs postgres server?

**UPDATE:**
I found a way to connect via localhost (charlies suggestion), it seems that `config.vm.network "forwarded_port"` only forwards ports to `localhost`. Additionally, I followed this guide:
<https://pseudoscripter.wordpress.com/2016/04/26/allow-remote-hosts-to-connect-to-postgresql-database-server-on-vagrant-box/>

and edited `postgresql.conf` so that it listens to all IPs, by adding this line:

```
listen_addresses = '*'         # what IP address(es) to listen on;
```

and edited `pg_hba.conf` to allow the guests IP address:

```
host    all             all             192.168.33.33/24        md5
```

^^ That step probably has nothing to do with why it works on `localhost:3333`. The steps from that guide didn't work connecting on `192.168.33.33:3333`, but I can connect on `localhost:3333`.

**SOLVED**
Rather than trying to access the server on the guest IP via the forwarded ports, it can be accessed on the guests port, so I can access the server on `192.168.33.33:5432` now. This didn't work for me when I first tried, so the steps in UPDATE 1 were required to make it accessible.



### Question Comments

=== COMMENTS ===
- (1) charli [Commented Jan 7, 2017 at 21:59]: AFAIK, Vagrant will bind the forwarded ports in localhost , so you should connect to localhost:3333
- (2) Horse O'Houlihan [Commented Jan 7, 2017 at 22:13]: Yeah you're right, that worked. It didn't work before, but I modified a few things so I'll update the original post. It would still be good to be able to use the IP of guest machine. There has to be a way to do that, but doing it like this works all the same. Thanks.


---


# Accepted Answer

Reading again your question, I have noticed the `private_network` configuration. This makes that your **guest host** has that IP, so you should be able to connect to 192.168.33.33:**5432**. PostgreSQL is listening on 5432 in the VM. Careful, your host should be on the same network to be reacheable. If not, you will need to add static routes between your host and the VM.

The `forwarded_port` option will map a port on your host with a port on your guest, so

```
config.vm.network "forwarded_port", guest: 5432, host: 3333
```

will map `localhost:3333` (or [any IP you have in your host](https://www.vagrantup.com/docs/networking/forwarded_ports.html)) to `192.168.33.33:5432`.

About the `pg_hba.conf` configuration, it prevents unauthorised accesses, but you can connect to the server, so the error message will differ.
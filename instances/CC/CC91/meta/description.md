# Connecting to AWS RDS instance using MySQL Workbench (MacOS)

# Question

I've created an RDS instance on AWS and am trying to connect to it using MySQL Workbench from my local machine. I've configured the RDS instance to be publicly accessible, it sits in a public subnet with access to an internet gateway, and its VPC security group accepts traffic from my IP address on port 3306. However, I cannot connect to the database (MySQL Workbench times out).

My RDS configuration:

[![enter image description here](images/CC91/vHHcr.png)](https://i.sstatic.net/vHHcr.png)

My security group configuration:

[![enter image description here](images/CC91/Dq660.png)](https://i.sstatic.net/Dq660.png)

The only way I can connect to it without issues is by configuring the security group to accept all traffic using IP 0.0.0.0/0 on port 3306, which has some obvious security concerns. I believe the fact that I can connect when the security group accepts all traffic proves that the problem is not with my ISP or any firewalls on my local network.

I feel like I've tried everything. Is there anything I'm missing?


---


# Accepted Answer

# Solution

For anyone using AWS RDS on a Mac, the solution to this problem is very straightforward. Just turn off Apple's Private Relay by going to `System Settings > 'Your Name' > iCloud > Private Relay`. This service routes your requests through multiple relays that encrypt your data and generate temporary IP addresses. The temporary IP addresses are what mess things up in this case.

I can't believe this took me a week to figure out. I hope I can save someone else some time :)
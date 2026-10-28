# How to shrink/purge ibdata1 file in MySQL

I use MySQL locally as a query tool for statistics in R. Each script creates a database and table, imports data, runs a query, and then drops them. Although the data is dropped, `ibdata1` keeps growing.

How can I reclaim the space and prevent temporary analysis tables from making `ibdata1` grow? The relevant MySQL setting should store each InnoDB table and its indexes in a separate tablespace so dropped tables release their files.

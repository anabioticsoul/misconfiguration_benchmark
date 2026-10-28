# DBMS: MySQL (no ver.) Case sensitivity: plain=mixed, delimited=exact Connection refused [closed]

# Question

**Closed.** This question is [not about programming or software development](/help/closed-questions). It is not currently accepting answers.

---

This question does not appear to be about [a specific programming problem, a software algorithm, or software tools primarily used by programmers](/help/on-topic). If you believe the question would be on-topic on [another Stack Exchange site](https://stackexchange.com/sites), you can leave a comment to explain where the question may be able to be answered.

Closed last year.

[Improve this question](/posts/75561162/edit)

Unable to connect to db using IntelliJ on mac m1.

Installed MySQL using Homebrew, I am able to access MySQL via terminal, I don't know what I am doing wrong.

I have tried reinstalling, changing the password, restarted my machine. but no hope

DBMS: MySQL (no ver.) Case sensitivity: plain=mixed, delimited=exact Connection refused



### Question Comments

=== COMMENTS ===
- (1) user1191247 [Commented Feb 24, 2023 at 22:36]: What params are you using when trying to connect using IntelliJ vs terminal? Please add details to your question, not in a comment. You could start by running SHOW VARIABLES LIKE 'bind_address'; when connected via terminal.
- (2) Wesley LeMahieu [Commented Feb 24, 2023 at 22:54]: Does this help? stackoverflow.com/questions/65646647/…
- (3) Musa Baloyi [Commented Feb 24, 2023 at 23:24]: I had tempered with my.cnf file and had a different bind_address


---


# Accepted Answer

If you are encountering issues with your MySQL database while using Docker, the problem may be caused by the MYSQL\_USER=root entry in your docker-compose.yaml file. This entry defines the user for your database environment and can create conflicts for the root user.

```
    db:
        image: mysql:8.0
        ports:
          - "3306:3306"
        environment:
          - MYSQL_ROOT_HOSTS=%
          - MYSQL_DATABASE=spring_boot_mysql
          - MYSQL_USER=root
          - MYSQL_ALLOW_EMPTY_PASSWORD=1
        volumes:
          - ./docker/volume_mysql:/var/lib/mysql
```

To resolve this issue, you should remove the MYSQL\_USER=root entry and instead use one of the following to manage the root user password:

* MYSQL\_ROOT\_PASSWORD
* MYSQL\_ALLOW\_EMPTY\_PASSWORD
* MYSQL\_RANDOM\_ROOT\_PASSWORD

During my search for a solution, I found that the **Docker log** provided a helpful error message:

*[ERROR] [Entrypoint]: MYSQL\_USER="root", MYSQL\_USER and MYSQL\_PASSWORD are for configuring a regular user and cannot be used for the root user.*

By removing MYSQL\_USER=root from the docker-compose.yaml file, the problem was resolved, and the database connection was established successfully.

Here is the final database definition:

```
    db:
        image: mysql:8.0
        ports:
          - "3306:3306"
        environment:
          - MYSQL_ROOT_HOSTS=%
          - MYSQL_DATABASE=spring_boot_mysql
          - MYSQL_ALLOW_EMPTY_PASSWORD=1
        volumes:
          - ./docker/volume_mysql:/var/lib/mysql
```

I hope this information helps you resolve your issue.
# Symfony 2.7 cache:clear command checks every database connection

# Question

I just have upgraded to symfony 2.7, and have a annoying behaviour.

Some connections in my config.yml are optionables, and describe foreign databases that are not intended to be used in every prod instances.

When doing a cache:clear , it seems that now every connections are checked, even if I don't want them to be active on a particular server.

When setting the --no-warmup option, the problem occurs half the time

```
php app/console cache:clear --env=prod --no-warmup --verbose
```

> [Doctrine\DBAL\Exception\ConnectionException]  
> An exception occured in driver: SQLSTATE[42000] [1049] Unknown
> database 'bal\_syncrho\_database'
>
> Exception trace: () at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Driver/AbstractMySQLDriver.php:103
> Doctrine\DBAL\Driver\AbstractMySQLDriver->convertException() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/DBALException.php:133
> Doctrine\DBAL\DBALException::driverException() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Driver/PDOMySql/Driver.php:47
> Doctrine\DBAL\Driver\PDOMySql\Driver->connect() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Connection.php:360
> Doctrine\DBAL\Connection->connect() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Connection.php:429
> Doctrine\DBAL\Connection->getDatabasePlatformVersion() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Connection.php:389
> Doctrine\DBAL\Connection->detectDatabasePlatform() at
> /var/www/ror3/vendor/doctrine/dbal/lib/Doctrine/DBAL/Connection.php:328
> Doctrine\DBAL\Connection->getDatabasePlatform() at
> /var/www/ror3/vendor/doctrine/orm/lib/Doctrine/ORM/Mapping/ClassMetadataFactory.php:763
> Doctrine\ORM\Mapping\ClassMetadataFactory->getTargetPlatform() at
> /var/www/ror3/vendor/doctrine/orm/lib/Doctrine/ORM/Mapping/ClassMetadataFactory.php:616
> Doctrine\ORM\Mapping\ClassMetadataFactory->completeIdGeneratorMapping()
> at
> /var/www/ror3/vendor/doctrine/orm/lib/Doctrine/ORM/Mapping/ClassMetadataFactory.php:174
> Doctrine\ORM\Mapping\ClassMetadataFactory->doLoadMetadata() at
> /var/www/ror3/vendor/doctrine/common/lib/Doctrine/Common/Persistence/Mapping/AbstractClassMetadataFactory.php:332
> Doctrine\Common\Persistence\Mapping\AbstractClassMetadataFactory->loadMetadata()
> at
> /var/www/ror3/vendor/doctrine/orm/lib/Doctrine/ORM/Mapping/ClassMetadataFactory.php:78
> Doctrine\ORM\Mapping\ClassMetadataFactory->loadMetadata() at
> /var/www/ror3/vendor/doctrine/common/lib/Doctrine/Common/Persistence/Mapping/AbstractClassMetadataFactory.php:216
> Doctrine\Common\Persistence\Mapping\AbstractClassMetadataFactory->getMetadataFor()
> at
> /var/www/ror3/vendor/doctrine/common/lib/Doctrine/Common/Persistence/Mapping/AbstractClassMetadataFactory.php:115
> Doctrine\Common\Persistence\Mapping\AbstractClassMetadataFactory->getAllMetadata()
> at
> /var/www/ror3/vendor/symfony/symfony/src/Symfony/Bridge/Doctrine/CacheWarmer/ProxyCacheWarmer.php:69
> Symfony\Bridge\Doctrine\CacheWarmer\ProxyCacheWarmer->warmUp() at
> /var/www/ror3/vendor/symfony/symfony/src/Symfony/Component/HttpKernel/CacheWarmer/CacheWarmerAggregate.php:48
> Symfony\Component\HttpKernel\CacheWarmer\CacheWarmerAggregate->warmUp()
> at /var/www/ror3/app/bootstrap.php.cache:2641
> Symfony\Component\HttpKernel\Kernel->initializeContainer() at
> /var/www/ror3/app/bootstrap.php.cache:2411
> Symfony\Component\HttpKernel\Kernel->boot() at
> /var/www/ror3/vendor/symfony/symfony/src/Symfony/Bundle/FrameworkBundle/Console/Application.php:70
> Symfony\Bundle\FrameworkBundle\Console\Application->doRun() at
> /var/www/ror3/vendor/symfony/symfony/src/Symfony/Component/Console/Application.php:120
> Symfony\Component\Console\Application->run() at  
> /var/www/ror3/app/console:27


---


# Accepted Answer

Doctrine is trying to determine the Database Platform Version.

You can avoid this behavior by adding the server version in the [Doctrine DBAL Configuration](http://symfony.com/doc/current/reference/configuration/doctrine.html#doctrine-dbal-configuration). From the doc:

> The server\_version option was added in Doctrine DBAL 2.5, which is
> used by DoctrineBundle 1.3. The value of this option should match your
> database server version (use postgres -V or psql -V command to find
> your PostgreSQL version and mysql -V to get your MySQL version).
>
> **If you don't define this option and haven't created your database yet, you may get PDOException errors because Doctrine will
> try to guess the database server version automatically and none is
> available.**

As example:

```
#config.yml

doctrine:
    dbal:
    ...
        server_version:       5.6
```

Hope this helps
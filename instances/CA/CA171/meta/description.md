# Enabling autocommit in PDO on a mysql with autocommit set to off

## Question

I've just been assigned to a legacy PHP codebase that worked without PDO.

Connections are done using this pattern:

```php
// Connect to MySQL Database
$con = new mysqli($host, $user, $password, $database);
 
// Check connection
if ($con->connect_error) {
    die("Connection failed: " . $con->connect_error);
}

$con->autocommit(true);
```

And using that `autocommit(true)`, even though the MySQL server is configured with `SET autocommit = 0`, works as expected.

Now I'm trying to migrate queries from plain SQL to prepared statements, so I wrote this

```php
$dsn = "mysql:host=$host;dbname=$database";
$pdo = new PDO($dsn, $user, $password);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, true);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, 1);
```

and the following example function

```php
function updateTeam($pdo, $name, $id)
{
    try {
        $data = [
            'name' => $name,
            'id' => $id
        ];
        $sql = "UPDATE teams SET name = :name WHERE id=:id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute($data);
        // $pdo->commit();
    }
    catch (PDOException $e) {
        db::$pdo->rollback();
        error_log('Failed: ' . $e->getMessage() );
    }
    catch (Exception $exc) {
        db::$pdo->rollback();
        error_log('Failed: ' . $exc->getMessage());
    }
}
```

doesn't commit. I have to uncomment the `$pdo->commit();` to make it work, which is something i do not want, because that will force me to change every single query at the app.

What am I missing on the PDO config?
I tried `var_dump($pdo->query('SELECT @@autocommit')->fetchAll());` and the result was

```text
array(1) { [0]=> array(2) { ["@@autocommit"]=> string(1) "0" [0]=> string(1) "0" } }
```

## Question Comments

- Your Common Sense: prepared statements are also supported by mysqli.
- Your Common Sense: `SET autocommit = 1` can be executed as a regular query.
- Dharman: exceptions could be rethrown if the updates must succeed.
- user2087103: the example was only for illustration.

## Accepted Answer

PDO's autocommit is not the same as MySQL's autocommit. If the MySQL server defaults `autocommit` to `0`, that does not change the default value of `PDO::ATTR_AUTOCOMMIT`, which is always `true`.

Changing `PDO::ATTR_AUTOCOMMIT` to the same value, or to a non-boolean/non-integer equivalent, is ignored. Both operations in the question are therefore no-ops because the PDO value already defaults to true.

Disabling and enabling the PDO attribute can make the driver issue the corresponding calls:

```php
$pdo = new PDO($dsn, $user, $password);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, false);
$pdo->setAttribute(PDO::ATTR_AUTOCOMMIT, true);
```

Alternatively, align the MySQL session directly:

```php
$pdo = new PDO($dsn, $user, $password);
$pdo->exec('SET autocommit = 1');
```

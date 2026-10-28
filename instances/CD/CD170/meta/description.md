# Heroku push of django app gets “No module named psycopg2.extensions”

I’m trying to push a Django app to Heroku and getting an import error while using PostgreSQL:

```text
ImportError: No module named psycopg2.extensions
```

The PostgreSQL add-on is provisioned and promoted to `DATABASE_URL`. The application’s `requirements.txt` currently contains:

```text
Django==1.4.2
wsgiref==0.1.2
dj-database-url==0.2.1
```

The database settings are loaded with `dj_database_url.config`, and the resulting settings use the `django.db.backends.postgresql_psycopg2` engine. During Django model validation, startup fails while importing `psycopg2.extensions`.

What is missing, and how should this be fixed?

## Accepted Answer

Add the PostgreSQL database adapter to `requirements.txt`:

```text
psycopg2==2.4.4
```

`psycopg2` is the database adapter that lets Python interface with PostgreSQL. Heroku provides the database service, but the adapter must be listed as an application dependency. The add-on itself is not the missing dependency; `dj-database-url` reads the provisioned database URL.

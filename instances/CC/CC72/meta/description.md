# Rector not finding anything to change (Converting Doctrine annotations to attributes)

Rector lists every entity in `src/Entity`, but reports no possible changes when processing Doctrine annotations with the annotations-to-attributes sets. The Rector configuration contains the Doctrine, Symfony, and Sensiolabs sets from the official tutorial, and the command is:

```text
vendor/bin/rector process src/Entity --dry-run --debug
```

The project is configured for PHP 7 with:

```json
"php": ">=7.2.5"
```

What configuration change makes Rector detect and convert the annotations to PHP attributes?

## Accepted answer

Change the PHP version in `composer.json` from PHP 7 to PHP 8:

```json
"php": "^8.0"
```

The answer notes that this is the needed change for Rector to detect the conversion.

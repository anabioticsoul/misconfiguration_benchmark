# Artisan command aborts with no output when reaching a model query

A Laravel Artisan command processes more than 50,000 rows from a `Question` model using `Question::orderBy('id')->get()` (or `Question::all()`). It works locally, and a single-row `find()` works in production, but the production command stops abruptly with no useful CLI or application log output when the complete result is loaded. The database connection and model are otherwise working.

What is happening, and what production-side setting or approach should be investigated?

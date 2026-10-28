import os
from urllib.parse import urlparse


def config(default=None):
    value = os.environ.get('DATABASE_URL', default)
    parsed = urlparse(value)
    return {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': parsed.path.lstrip('/') or 'cd170',
        'USER': parsed.username or '',
        'PASSWORD': parsed.password or '',
        'HOST': parsed.hostname or 'localhost',
        'PORT': parsed.port or 5432,
    }

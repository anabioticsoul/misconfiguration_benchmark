SECRET_KEY = 'cd170-synthetic-secret'
DEBUG = False
ROOT_URLCONF = 'urls'
INSTALLED_APPS = []

import sys

import dj_database_url

with open('/opt/cd170/requirements.txt') as requirements_file:
    if any(line.startswith('psycopg2==') for line in requirements_file):
        sys.path.insert(0, '/opt/cd170/vendor')

import psycopg2.extensions

DATABASES = {
    'default': dj_database_url.config(default='postgres://localhost')
}

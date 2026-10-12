"""
Django settings for config project (SantéGuinée backend).

MVP rebuild per le cahier des charges. Voir README.md à la racine du
dépôt pour le détail des simplifications volontaires de cette passe
(pas de PostGIS/GeoDjango, pas de fournisseur SMS réel, etc.).
"""

import os
from pathlib import Path

import dj_database_url
from decouple import config as env

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = env("SECRET_KEY", default="django-insecure-dev-only-change-me")

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = env("DEBUG", default=True, cast=bool)

ALLOWED_HOSTS = env("ALLOWED_HOSTS", default="*").split(",")


# Application definition

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "django_filters",
    "corsheaders",
    # SantéGuinée apps
    "accounts",
    "directory",
    "scheduling",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"


# Database
# https://docs.djangoproject.com/en/5.2/ref/settings/#databases
#
# Simplification volontaire (voir README) : SQLite par défaut pour le
# développement et les tests. DATABASE_URL (ex. postgres://...) bascule
# vers PostgreSQL, notamment via le docker-compose.yml fourni à la racine.

DATABASE_URL = env("DATABASE_URL", default=None)
if DATABASE_URL:
    DATABASES = {
        "default": dj_database_url.parse(DATABASE_URL, conn_max_age=600)
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }


# Custom user model (login par numéro de téléphone, cf. accounts app)
AUTH_USER_MODEL = "accounts.Utilisateur"


# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = "fr"

# Note: la Guinée (Conakry) est sur GMT (UTC+0) toute l'année, sans
# changement d'heure. On utilise donc directement UTC comme fuseau de
# référence côté serveur (cf. cahier des charges, section horaires).
TIME_ZONE = "UTC"

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = "static/"

# Default primary key field type
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"


# Django REST Framework
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
}

if "rest_framework.authtoken" not in INSTALLED_APPS:
    INSTALLED_APPS.append("rest_framework.authtoken")

CORS_ALLOW_ALL_ORIGINS = DEBUG

# ---------------------------------------------------------------------------
# Règles métier du cahier des charges (constantes paramétrables)
# ---------------------------------------------------------------------------

# RG-05 : fenêtre de génération des créneaux à venir (en jours), 14 à 90.
SLOT_GENERATION_WINDOW_DAYS = env("SLOT_GENERATION_WINDOW_DAYS", default=60, cast=int)

# RG-06 : durée du verrou posé sur un créneau sélectionné (en minutes).
SLOT_LOCK_MINUTES = env("SLOT_LOCK_MINUTES", default=5, cast=int)

# RG-07 : nombre maximal de rendez-vous futurs avec le même praticien.
MAX_FUTURE_RDV_PAR_PRATICIEN = env("MAX_FUTURE_RDV_PAR_PRATICIEN", default=3, cast=int)

# RG-08 : délai minimal (en heures) avant le début du créneau pour réserver.
MIN_HEURES_AVANT_RESERVATION = env("MIN_HEURES_AVANT_RESERVATION", default=1, cast=int)

# RG-09 : délai (en heures) pour annuler gratuitement, paramétrable 2-48h.
DELAI_ANNULATION_GRATUITE_HEURES = env(
    "DELAI_ANNULATION_GRATUITE_HEURES", default=24, cast=int
)

# RG-11 : nombre d'absences non justifiées sur la période de référence
# déclenchant l'exigence d'un acompte.
MAX_ABSENCES_AVANT_ACOMPTE = env("MAX_ABSENCES_AVANT_ACOMPTE", default=3, cast=int)
PERIODE_ABSENCES_MOIS = env("PERIODE_ABSENCES_MOIS", default=6, cast=int)

# RG-12 : délai après l'heure de début d'un rendez-vous au-delà duquel il
# est automatiquement marqué "absent" si le patient n'est pas arrivé.
DELAI_NO_SHOW_MINUTES = env("DELAI_NO_SHOW_MINUTES", default=30, cast=int)

# RG-24 : nombre maximal de "proches" gérés par un titulaire.
MAX_PROCHES_PAR_TITULAIRE = env("MAX_PROCHES_PAR_TITULAIRE", default=10, cast=int)

# Code SMS : durée de validité (minutes) et nombre d'essais max.
SMS_CODE_EXPIRY_MINUTES = env("SMS_CODE_EXPIRY_MINUTES", default=5, cast=int)
SMS_CODE_MAX_ATTEMPTS = env("SMS_CODE_MAX_ATTEMPTS", default=3, cast=int)

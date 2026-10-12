"""Tests du flux de connexion par code SMS (expiration, tentatives,
usage unique) - accounts/sms.py et accounts/models.py::CodeSMS."""

import datetime

import pytest
from django.test import override_settings
from django.utils import timezone

from accounts import sms
from accounts.models import CodeSMS, Utilisateur

pytestmark = pytest.mark.django_db

TELEPHONE = "+224620123456"


class TestEnvoiEtVerificationCode:
    def test_send_code_cree_un_code_sms_hashe(self, capsys):
        code_sms = sms.send_code(TELEPHONE)
        assert code_sms.telephone == TELEPHONE
        # Le code en clair n'est jamais stocké : code_hash est un hash Django.
        assert code_sms.code_hash.startswith("pbkdf2_") or "$" in code_sms.code_hash
        captured = capsys.readouterr()
        assert "SMS to" in captured.out

    def test_verification_avec_bon_code_cree_l_utilisateur(self):
        _code_sms, code_en_clair = CodeSMS.generer(TELEPHONE, duree_minutes=5)

        ok, utilisateur = sms.verify_code(TELEPHONE, code_en_clair)

        assert ok is True
        assert utilisateur is not None
        assert utilisateur.telephone == TELEPHONE
        assert Utilisateur.objects.filter(telephone=TELEPHONE).count() == 1

    def test_verification_avec_mauvais_code_echoue(self):
        CodeSMS.generer(TELEPHONE, duree_minutes=5)
        ok, utilisateur = sms.verify_code(TELEPHONE, "000000")
        assert ok is False
        assert utilisateur is None


class TestExpirationEtTentatives:
    @override_settings(SMS_CODE_MAX_ATTEMPTS=3)
    def test_code_expire_est_refuse(self):
        from django.contrib.auth.hashers import make_password

        code_sms = CodeSMS.objects.create(
            telephone=TELEPHONE,
            code_hash=make_password("123456"),
            expires_at=timezone.now() - datetime.timedelta(seconds=1),
        )

        assert code_sms.verifier("123456", max_attempts=3) is False

    @override_settings(SMS_CODE_MAX_ATTEMPTS=3)
    def test_trois_tentatives_echouees_bloquent_le_code(self):
        from django.contrib.auth.hashers import make_password

        code_sms = CodeSMS.objects.create(
            telephone=TELEPHONE,
            code_hash=make_password("123456"),
            expires_at=timezone.now() + datetime.timedelta(minutes=5),
        )

        assert code_sms.verifier("000000", max_attempts=3) is False
        assert code_sms.verifier("111111", max_attempts=3) is False
        assert code_sms.verifier("222222", max_attempts=3) is False
        # La 4e tentative (même avec le bon code) est refusée : plafond atteint.
        assert code_sms.verifier("123456", max_attempts=3) is False

    def test_code_a_usage_unique(self):
        from django.contrib.auth.hashers import make_password

        code_sms = CodeSMS.objects.create(
            telephone=TELEPHONE,
            code_hash=make_password("123456"),
            expires_at=timezone.now() + datetime.timedelta(minutes=5),
        )
        assert code_sms.verifier("123456", max_attempts=3) is True
        # Une deuxième vérification, même avec le bon code, doit échouer.
        assert code_sms.verifier("123456", max_attempts=3) is False

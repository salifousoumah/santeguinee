"""Service d'envoi de codes de connexion par SMS.

Point d'intégration MVP : aucun agrégateur SMS réel n'est branché pour
cette passe (cf. README, simplifications volontaires). `send_code`
se contente d'afficher le code dans la console/les logs, exactement
comme le faisait la session précédente dont le code a été perdu.

>>> POINT D'INTÉGRATION FUTUR <<<
Pour brancher un vrai fournisseur (Orange Guinée, MTN, Twilio, etc.),
remplacer le corps de `send_code` par un appel HTTP à l'agrégateur,
sans changer la signature de la fonction ni le flux appelant
(accounts/views.py), qui ne connaît pas le mécanisme d'envoi.
"""

import logging

from django.conf import settings
from django.utils import timezone

from .models import CodeSMS, Utilisateur

logger = logging.getLogger("accounts.sms")


def send_code(phone):
    """Génère un code à 6 chiffres, le stocke (hashé) et l'envoie par "SMS".

    Retourne l'instance CodeSMS créée. Le code en clair n'est jamais
    renvoyé par cette fonction ni persisté ailleurs que dans le message
    de log ci-dessous (qui simule l'envoi SMS pour le développement).
    """
    code_sms, code = CodeSMS.generer(phone, settings.SMS_CODE_EXPIRY_MINUTES)

    # --- Simulation d'envoi SMS (MVP) ---------------------------------
    # En production, remplacer cette ligne par l'appel à un agrégateur SMS.
    message = f"SMS to {phone}: code {code}"
    logger.info(message)
    print(message)  # noqa: T201 - simulation volontaire, visible en dev/tests
    # -------------------------------------------------------------------

    return code_sms


def verify_code(phone, code):
    """Vérifie un code SMS pour `phone` et renvoie (ok, utilisateur_ou_None).

    Règles appliquées (voir accounts.models.CodeSMS.verifier) :
    - expiration à settings.SMS_CODE_EXPIRY_MINUTES minutes,
    - settings.SMS_CODE_MAX_ATTEMPTS tentatives maximum,
    - usage unique.

    En cas de succès, crée l'Utilisateur correspondant au numéro s'il
    n'existe pas encore (RG-24 : un numéro = un seul compte).
    """
    code_sms = (
        CodeSMS.objects.filter(telephone=phone, consumed=False)
        .order_by("-cree_le")
        .first()
    )
    if code_sms is None:
        return False, None

    ok = code_sms.verifier(code, settings.SMS_CODE_MAX_ATTEMPTS)
    if not ok:
        return False, None

    utilisateur, _cree = Utilisateur.objects.get_or_create(telephone=phone)
    utilisateur.derniere_connexion = timezone.now()
    utilisateur.save(update_fields=["derniere_connexion"])
    return True, utilisateur

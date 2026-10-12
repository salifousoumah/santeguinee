"""Vues du module comptes : flux de connexion par code SMS, gestion des
patients et des liens "proches".
"""

from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from . import sms
from .models import LienProche, Patient
from .serializers import (
    DemandeCodeSerializer,
    LienProcheSerializer,
    PatientSerializer,
    UtilisateurSerializer,
    VerificationCodeSerializer,
)


class DemandeCodeView(APIView):
    """POST /api/accounts/auth/demande-code/ {telephone}

    Déclenche l'envoi (simulé, voir accounts/sms.py) d'un code à 6
    chiffres valable settings.SMS_CODE_EXPIRY_MINUTES minutes.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = DemandeCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        telephone = serializer.validated_data["telephone"]
        sms.send_code(telephone)
        return Response(
            {"detail": "Code envoyé par SMS (voir logs serveur en environnement de démo)."},
            status=status.HTTP_200_OK,
        )


class VerificationCodeView(APIView):
    """POST /api/accounts/auth/verification-code/ {telephone, code}

    Vérifie le code et renvoie un token d'authentification DRF en cas
    de succès (RG implicite : 5 min / 3 tentatives / usage unique, voir
    accounts/models.py::CodeSMS).
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerificationCodeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        telephone = serializer.validated_data["telephone"]
        code = serializer.validated_data["code"]

        ok, utilisateur = sms.verify_code(telephone, code)
        if not ok:
            return Response(
                {"detail": "Code invalide, expiré ou nombre de tentatives dépassé."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        token, _ = Token.objects.get_or_create(user=utilisateur)
        return Response(
            {
                "token": token.key,
                "utilisateur": UtilisateurSerializer(utilisateur).data,
            }
        )


class PatientViewSet(viewsets.ModelViewSet):
    """CRUD sur les patients gérés par l'utilisateur connecté : son
    propre profil patient (utilisateur=request.user) et ses "proches"
    (via LienProche, RG-24 : max settings.MAX_PROCHES_PAR_TITULAIRE).
    """

    serializer_class = PatientSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        utilisateur = self.request.user
        proches_ids = LienProche.objects.filter(
            titulaire__utilisateur=utilisateur
        ).values_list("patient_id", flat=True)
        return Patient.objects.filter(
            models_q_utilisateur_ou_proche(utilisateur, proches_ids)
        )

    def perform_create(self, serializer):
        serializer.save(utilisateur=self.request.user)


def models_q_utilisateur_ou_proche(utilisateur, proches_ids):
    from django.db.models import Q

    return Q(utilisateur=utilisateur) | Q(id__in=list(proches_ids))


class LienProcheViewSet(viewsets.ModelViewSet):
    """Gestion des liens "proche" (RG-24)."""

    serializer_class = LienProcheSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return LienProche.objects.filter(titulaire__utilisateur=self.request.user)

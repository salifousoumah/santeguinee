"""Vues du module prise de rendez-vous : consultation des créneaux,
verrouillage, confirmation, "mes rendez-vous", annulation, liste
d'attente.
"""

from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import LienProche, Patient
from directory.models import Exercice

from .models import Creneau, ListeAttente, RendezVous, TypeConsultation
from .serializers import (
    ConfirmerRendezVousSerializer,
    CreneauSerializer,
    ListeAttenteSerializer,
    RendezVousSerializer,
)
from .services import ReglMetierError, annuler_rendez_vous, liberer_verrous_expires
from .services import confirmer_rendez_vous as confirmer_rendez_vous_service
from .services import verrouiller_creneau


def _patients_autorises(utilisateur):
    """UUIDs des Patient que `utilisateur` est autorisé à représenter :
    son propre profil + ses "proches" (RG-24)."""
    ids = set(
        Patient.objects.filter(utilisateur=utilisateur).values_list("id", flat=True)
    )
    ids |= set(
        LienProche.objects.filter(titulaire__utilisateur=utilisateur).values_list(
            "patient_id", flat=True
        )
    )
    return ids


class CreneauListView(generics.ListAPIView):
    """GET /api/scheduling/creneaux/?exercice=<uuid>&statut=libre

    Libère au préalable les verrous expirés (RG-06) pour que la liste
    reflète la disponibilité réelle.
    """

    serializer_class = CreneauSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        liberer_verrous_expires()
        qs = Creneau.objects.all().order_by("debut")
        params = self.request.query_params
        exercice = params.get("exercice")
        if exercice:
            qs = qs.filter(exercice_id=exercice)
        statut = params.get("statut", Creneau.LIBRE)
        if statut:
            qs = qs.filter(statut=statut)
        return qs


class VerrouillerCreneauView(APIView):
    """POST /api/scheduling/creneaux/<uuid:creneau_id>/verrouiller/

    RG-06 : verrouille le créneau pendant settings.SLOT_LOCK_MINUTES
    minutes.
    """

    permission_classes = [permissions.AllowAny]

    def post(self, request, creneau_id):
        try:
            creneau = verrouiller_creneau(creneau_id)
        except Creneau.DoesNotExist:
            return Response({"detail": "Créneau introuvable."}, status=status.HTTP_404_NOT_FOUND)
        except ReglMetierError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_409_CONFLICT)
        return Response(CreneauSerializer(creneau).data)


class ConfirmerRendezVousView(APIView):
    """POST /api/scheduling/rendez-vous/confirmer/

    Corps : {patient_id, creneau_id, exercice_id, type_consultation_id?,
    motif?, canal?}

    Applique RG-06/07/08. Le patient visé doit être le compte connecté
    ou un de ses "proches" (RG-24).
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = ConfirmerRendezVousSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if data["patient_id"] not in _patients_autorises(request.user):
            return Response(
                {"detail": "Vous n'êtes pas autorisé à réserver pour ce patient."},
                status=status.HTTP_403_FORBIDDEN,
            )

        patient = get_object_or_404(Patient, pk=data["patient_id"])
        exercice = get_object_or_404(Exercice, pk=data["exercice_id"])
        type_consultation = None
        if data.get("type_consultation_id"):
            type_consultation = get_object_or_404(
                TypeConsultation, pk=data["type_consultation_id"]
            )

        try:
            rdv = confirmer_rendez_vous_service(
                patient=patient,
                creneau_id=data["creneau_id"],
                exercice=exercice,
                type_consultation=type_consultation,
                motif=data.get("motif", ""),
                canal=data.get("canal", RendezVous.APPLICATION),
            )
        except Creneau.DoesNotExist:
            return Response({"detail": "Créneau introuvable."}, status=status.HTTP_404_NOT_FOUND)
        except ReglMetierError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_409_CONFLICT)

        return Response(RendezVousSerializer(rdv).data, status=status.HTTP_201_CREATED)


class MesRendezVousView(generics.ListAPIView):
    """GET /api/scheduling/rendez-vous/mes-rendez-vous/

    Rendez-vous du patient connecté et de ses "proches".
    """

    serializer_class = RendezVousSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        patients_ids = _patients_autorises(self.request.user)
        return RendezVous.objects.filter(patient_id__in=patients_ids).order_by("-cree_le")


class AnnulerRendezVousView(APIView):
    """POST /api/scheduling/rendez-vous/<uuid:rdv_id>/annuler/ {motif?}

    RG-09 : annulation gratuite jusqu'à
    settings.DELAI_ANNULATION_GRATUITE_HEURES heures avant le créneau ;
    au-delà, l'éventuel acompte est marqué perdu.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, rdv_id):
        rdv = get_object_or_404(RendezVous, pk=rdv_id)
        if rdv.patient_id not in _patients_autorises(request.user):
            return Response(
                {"detail": "Vous n'êtes pas autorisé à annuler ce rendez-vous."},
                status=status.HTTP_403_FORBIDDEN,
            )
        rdv = annuler_rendez_vous(
            rdv, utilisateur=request.user, motif=request.data.get("motif", "")
        )
        return Response(RendezVousSerializer(rdv).data)


class ListeAttenteViewSet(viewsets.ModelViewSet):
    serializer_class = ListeAttenteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ListeAttente.objects.filter(
            patient_id__in=_patients_autorises(self.request.user)
        )

"""Vues de recherche dans l'annuaire (module M1, US-01 à US-04).

Seuls les établissements/praticiens `statut_verification=verifie`
apparaissent dans les résultats ("les établissements non vérifiés sont
masqués", cf. cahier des charges).
"""

from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import Etablissement, Praticien
from .serializers import EtablissementSerializer, PraticienSerializer
from .utils import est_ouvert_maintenant, haversine_km, texte_correspond


class EtablissementSearchView(generics.ListAPIView):
    """GET /api/directory/etablissements/

    Paramètres de requête :
    - q : texte libre (nom, repère), tolérant aux accents manquants
    - specialite : code d'une Specialite (recherche via les Service /
      Exercice de l'établissement)
    - zone : UUID d'une Zone (quartier/commune)
    - secteur : public|prive|confessionnel|ong
    - urgences_24h : true|false
    - ouvert_maintenant : true|false
    - lat, lon : tri par distance (Haversine) si fournis
    """

    serializer_class = EtablissementSerializer
    permission_classes = [AllowAny]

    def get_base_queryset(self):
        qs = (
            Etablissement.objects.filter(statut_verification=Etablissement.VERIFIE)
            .select_related("quartier")
            .prefetch_related(
                "services__specialite",
                "exercices__praticien__specialites",
                "horaires",
                "gardes",
            )
        )

        params = self.request.query_params

        zone = params.get("zone")
        if zone:
            qs = qs.filter(quartier_id=zone)

        secteur = params.get("secteur")
        if secteur:
            qs = qs.filter(secteur=secteur)

        if params.get("urgences_24h") is not None:
            valeur = params.get("urgences_24h").lower() in ("true", "1", "oui")
            qs = qs.filter(urgences_24h=valeur)

        specialite = params.get("specialite")
        if specialite:
            ids = set(
                qs.filter(services__specialite__code=specialite).values_list("id", flat=True)
            ) | set(
                qs.filter(exercices__praticien__specialites__code=specialite).values_list(
                    "id", flat=True
                )
            )
            qs = qs.filter(id__in=ids)

        return qs.distinct()

    # get_queryset is also required by DRF's pagination/filter machinery.
    def get_queryset(self):
        return self.get_base_queryset()

    def list(self, request, *args, **kwargs):
        queryset = list(self.get_base_queryset())

        q = request.query_params.get("q")
        if q:
            queryset = [etab for etab in queryset if self._correspond(q, etab)]

        ouvert_maintenant = request.query_params.get("ouvert_maintenant")
        if ouvert_maintenant is not None:
            attendu = ouvert_maintenant.lower() in ("true", "1", "oui")
            queryset = [e for e in queryset if est_ouvert_maintenant(e) == attendu]

        lat = request.query_params.get("lat")
        lon = request.query_params.get("lon")
        if lat and lon:
            lat, lon = float(lat), float(lon)
            for etab in queryset:
                etab.distance_km = haversine_km(lat, lon, etab.latitude, etab.longitude)
            queryset.sort(
                key=lambda e: (
                    e.distance_km is None,
                    e.distance_km if e.distance_km is not None else 0,
                )
            )

        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @staticmethod
    def _correspond(q, etablissement):
        """Texte libre : nom/repère de l'établissement, mais aussi les
        libellés (grand public ou médical) des spécialités qu'on y
        trouve, pour que "pediatre" retrouve un établissement proposant
        de la "Pédiatrie" même sans correspondance dans son nom."""
        if texte_correspond(q, etablissement.nom, etablissement.repere):
            return True
        libelles = []
        for service in etablissement.services.all():
            if service.specialite_id:
                libelles.append(service.specialite.libelle)
                libelles.append(service.specialite.libelle_grand_public)
        for exercice in etablissement.exercices.all():
            for specialite in exercice.praticien.specialites.all():
                libelles.append(specialite.libelle)
                libelles.append(specialite.libelle_grand_public)
        return texte_correspond(q, *libelles)


class PraticienSearchView(generics.ListAPIView):
    """GET /api/directory/praticiens/

    Paramètres : q (nom/prénoms), specialite (code), profession.
    """

    serializer_class = PraticienSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = Praticien.objects.filter(
            statut_verification=Praticien.VERIFIE
        ).prefetch_related("specialites", "exercices")

        params = self.request.query_params
        specialite = params.get("specialite")
        if specialite:
            qs = qs.filter(specialites__code=specialite)

        profession = params.get("profession")
        if profession:
            qs = qs.filter(profession=profession)

        return qs.distinct()

    def list(self, request, *args, **kwargs):
        queryset = list(self.get_queryset())
        q = request.query_params.get("q")
        if q:
            queryset = [p for p in queryset if texte_correspond(q, p.nom, p.prenoms)]

        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

from rest_framework import serializers

from .models import Etablissement, Exercice, Praticien, Specialite, Zone


class ZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = Zone
        fields = ["id", "type", "nom", "parent"]


class SpecialiteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Specialite
        fields = ["id", "code", "libelle", "libelle_grand_public", "icone"]


class EtablissementSerializer(serializers.ModelSerializer):
    quartier = ZoneSerializer(read_only=True)
    distance_km = serializers.SerializerMethodField()
    ouvert_maintenant = serializers.SerializerMethodField()

    class Meta:
        model = Etablissement
        fields = [
            "id",
            "nom",
            "type",
            "secteur",
            "latitude",
            "longitude",
            "repere",
            "quartier",
            "telephones",
            "urgences_24h",
            "moyens_paiement",
            "statut_verification",
            "distance_km",
            "ouvert_maintenant",
        ]

    def get_distance_km(self, obj):
        return getattr(obj, "distance_km", None)

    def get_ouvert_maintenant(self, obj):
        from .utils import est_ouvert_maintenant

        return est_ouvert_maintenant(obj)


class ExerciceSerializer(serializers.ModelSerializer):
    etablissement_nom = serializers.CharField(source="etablissement.nom", read_only=True)

    class Meta:
        model = Exercice
        fields = [
            "id",
            "praticien",
            "etablissement",
            "etablissement_nom",
            "service",
            "tarif_indicatif_gnf",
            "actif",
        ]


class PraticienSerializer(serializers.ModelSerializer):
    specialites = SpecialiteSerializer(many=True, read_only=True)
    exercices = ExerciceSerializer(many=True, read_only=True)

    class Meta:
        model = Praticien
        fields = [
            "id",
            "civilite",
            "nom",
            "prenoms",
            "profession",
            "numero_ordre",
            "langues",
            "presentation",
            "statut_verification",
            "specialites",
            "exercices",
        ]

from rest_framework import serializers

from .models import Creneau, ListeAttente, RendezVous, TypeConsultation


class TypeConsultationSerializer(serializers.ModelSerializer):
    class Meta:
        model = TypeConsultation
        fields = [
            "id",
            "exercice",
            "libelle",
            "duree_min",
            "tarif_gnf",
            "reservable_en_ligne",
            "acompte_gnf",
        ]


class CreneauSerializer(serializers.ModelSerializer):
    class Meta:
        model = Creneau
        fields = [
            "id",
            "exercice",
            "debut",
            "fin",
            "statut",
            "verrou_expire_le",
            "en_ligne",
        ]


class RendezVousSerializer(serializers.ModelSerializer):
    class Meta:
        model = RendezVous
        fields = [
            "id",
            "patient",
            "creneau",
            "exercice",
            "type_consultation",
            "motif",
            "statut",
            "canal",
            "depot_requis",
            "depot_perdu",
            "motif_annulation",
            "cree_le",
        ]
        read_only_fields = [
            "id",
            "statut",
            "depot_requis",
            "depot_perdu",
            "motif_annulation",
            "cree_le",
        ]


class ConfirmerRendezVousSerializer(serializers.Serializer):
    patient_id = serializers.UUIDField()
    creneau_id = serializers.UUIDField()
    exercice_id = serializers.UUIDField()
    type_consultation_id = serializers.UUIDField(required=False, allow_null=True)
    motif = serializers.CharField(required=False, allow_blank=True, default="")
    canal = serializers.ChoiceField(
        choices=RendezVous.CANAL_CHOICES, default=RendezVous.APPLICATION
    )


class ListeAttenteSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListeAttente
        fields = ["id", "patient", "exercice", "date_souhaitee", "statut", "notifie_le"]
        read_only_fields = ["id", "statut", "notifie_le"]

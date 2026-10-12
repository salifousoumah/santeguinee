from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from .models import LienProche, Patient, Utilisateur


class DemandeCodeSerializer(serializers.Serializer):
    telephone = serializers.CharField()


class VerificationCodeSerializer(serializers.Serializer):
    telephone = serializers.CharField()
    code = serializers.CharField(min_length=6, max_length=6)


class UtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = ["id", "telephone", "email", "langue", "statut", "derniere_connexion"]


class PatientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = [
            "id",
            "numero_sante",
            "nom",
            "prenoms",
            "sexe",
            "date_naissance",
            "telephone",
            "quartier",
            "utilisateur",
        ]
        read_only_fields = ["id", "numero_sante", "utilisateur"]


class LienProcheSerializer(serializers.ModelSerializer):
    class Meta:
        model = LienProche
        fields = ["id", "titulaire", "patient", "lien", "droits"]

    def validate(self, attrs):
        instance = LienProche(**attrs)
        try:
            instance.clean()  # déclenche RG-24 (max proches) + autres règles
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        return attrs

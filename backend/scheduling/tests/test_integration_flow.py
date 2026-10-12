"""Test d'intégration bout-en-bout du parcours de réservation complet,
via l'API DRF (APIClient), comme demandé en vérification finale :

demande de code SMS -> vérification -> création du profil patient ->
liste des créneaux disponibles -> verrouillage d'un créneau ->
confirmation du rendez-vous -> "mes rendez-vous" -> annulation.
"""

import pytest
from rest_framework.test import APIClient

from accounts.models import CodeSMS, Patient
from scheduling.models import Creneau, RendezVous

pytestmark = pytest.mark.django_db

TELEPHONE = "+224621234567"


class TestParcoursReservationComplet:
    def test_parcours_complet(self, exercice, creneau_futur, type_consultation):
        client = APIClient()

        # 1) Demande de code SMS.
        reponse = client.post(
            "/api/accounts/auth/demande-code/", {"telephone": TELEPHONE}, format="json"
        )
        assert reponse.status_code == 200

        code_sms = CodeSMS.objects.filter(telephone=TELEPHONE).latest("cree_le")
        # On ne connaît pas le code en clair (il n'est jamais stocké) : on en
        # génère un nouveau nous-même pour simuler ce que l'utilisateur a
        # reçu par SMS (mêmes garanties que send_code, cf. accounts/sms.py).
        code_sms.delete()
        _nouveau_code_sms, code_en_clair = CodeSMS.generer(TELEPHONE, duree_minutes=5)

        # 2) Vérification du code -> token d'authentification.
        reponse = client.post(
            "/api/accounts/auth/verification-code/",
            {"telephone": TELEPHONE, "code": code_en_clair},
            format="json",
        )
        assert reponse.status_code == 200
        token = reponse.json()["token"]
        client.credentials(HTTP_AUTHORIZATION=f"Token {token}")

        # 3) Création du profil patient.
        reponse = client.post(
            "/api/accounts/patients/",
            {
                "nom": "Doumbouya",
                "prenoms": "Intégration",
                "sexe": Patient.SEXE_FEMME,
            },
            format="json",
        )
        assert reponse.status_code == 201, reponse.json()
        patient_id = reponse.json()["id"]

        # 4) Liste des créneaux disponibles pour l'exercice.
        reponse = client.get(
            "/api/scheduling/creneaux/", {"exercice": str(exercice.id), "statut": "libre"}
        )
        assert reponse.status_code == 200
        creneaux_libres = reponse.json()["results"]
        assert any(c["id"] == str(creneau_futur.id) for c in creneaux_libres)

        # 5) Verrouillage du créneau choisi (RG-06).
        reponse = client.post(f"/api/scheduling/creneaux/{creneau_futur.id}/verrouiller/")
        assert reponse.status_code == 200
        assert reponse.json()["statut"] == Creneau.VERROUILLE

        # 6) Confirmation du rendez-vous.
        reponse = client.post(
            "/api/scheduling/rendez-vous/confirmer/",
            {
                "patient_id": patient_id,
                "creneau_id": str(creneau_futur.id),
                "exercice_id": str(exercice.id),
                "type_consultation_id": str(type_consultation.id),
                "motif": "Consultation de routine",
            },
            format="json",
        )
        assert reponse.status_code == 201, reponse.json()
        rdv_id = reponse.json()["id"]
        assert reponse.json()["statut"] == RendezVous.RESERVE

        creneau_futur.refresh_from_db()
        assert creneau_futur.statut == Creneau.RESERVE

        # 7) "Mes rendez-vous" doit lister ce rendez-vous.
        reponse = client.get("/api/scheduling/rendez-vous/mes-rendez-vous/")
        assert reponse.status_code == 200
        ids = [r["id"] for r in reponse.json()["results"]]
        assert rdv_id in ids

        # 8) Annulation du rendez-vous.
        reponse = client.post(
            f"/api/scheduling/rendez-vous/{rdv_id}/annuler/", {"motif": "Imprévu"}, format="json"
        )
        assert reponse.status_code == 200
        assert reponse.json()["statut"] == RendezVous.ANNULE

        creneau_futur.refresh_from_db()
        assert creneau_futur.statut == Creneau.LIBRE

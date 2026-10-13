#!/usr/bin/env bash
# Simule un parcours patient complet contre l'API SantéGuinée réelle :
# SMS -> profil -> recherche -> verrouillage d'un créneau -> réservation
# -> "mes rendez-vous" -> annulation.
#
# Seule l'étape du code SMS reste manuelle (le code n'est jamais stocké
# en clair côté serveur, par sécurité — RG du module comptes). Il faut
# le lire dans le terminal où tourne ./run.sh (ou manage.py runserver)
# et le coller ici quand demandé.
#
# Prérequis : curl, jq, un backend qui tourne (./run.sh ou
# manage.py runserver) et seed_demo déjà exécuté.
#
# Usage :
#   ./test_parcours_patient.sh                        # port 8001 par défaut
#   BASE_URL=http://127.0.0.1:8000/api ./test_parcours_patient.sh
#   TELEPHONE=+224655000111 ./test_parcours_patient.sh

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8001/api}"
TELEPHONE="${TELEPHONE:-+224621234567}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}==>${NC} $1"; }
warn()  { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
error() { echo -e "${RED}[ERREUR]${NC} $1"; }

if ! command -v jq >/dev/null 2>&1; then
  error "jq n'est pas installé. Installez-le : sudo apt install jq"
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  error "curl n'est pas installé. Installez-le : sudo apt install curl"
  exit 1
fi

# Petit helper : appelle l'API, affiche une erreur lisible si le code
# HTTP n'est pas celui attendu, sinon renvoie le corps JSON sur stdout.
api_call() {
  local method="$1" path="$2" expected="$3" data="${4:-}" auth="${5:-}"
  local args=(-s -w '\n%{http_code}' -X "$method" "${BASE_URL}${path}")
  args+=(-H "Content-Type: application/json")
  [[ -n "$auth" ]] && args+=(-H "Authorization: Token ${auth}")
  [[ -n "$data" ]] && args+=(-d "$data")

  local response status body
  response=$(curl "${args[@]}")
  status=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [[ "$status" != "$expected" ]]; then
    error "$method $path -> HTTP $status (attendu $expected)"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
  fi
  echo "$body"
}

echo
echo -e "${BOLD}Parcours patient — SantéGuinée${NC}  (API : $BASE_URL, téléphone : $TELEPHONE)"
echo

# 1) Demande de code SMS -----------------------------------------------------
info "1/8 Demande d'un code SMS..."
api_call POST "/accounts/auth/demande-code/" 200 "{\"telephone\": \"${TELEPHONE}\"}" > /dev/null
warn "Allez voir le terminal où tourne le serveur (./run.sh) : vous y trouverez"
warn "une ligne du type 'SMS to ${TELEPHONE}: code 123456'."
read -rp "Collez le code à 6 chiffres ici : " CODE

# 2) Vérification du code -> token -------------------------------------------
info "2/8 Vérification du code..."
VERIF=$(api_call POST "/accounts/auth/verification-code/" 200 \
  "{\"telephone\": \"${TELEPHONE}\", \"code\": \"${CODE}\"}")
TOKEN=$(echo "$VERIF" | jq -r '.token')
info "Connecté. Token : ${TOKEN:0:8}..."

# 3) Création (ou réutilisation) du profil patient ---------------------------
info "3/8 Création du profil patient..."
EXISTANTS=$(api_call GET "/accounts/patients/" 200 "" "$TOKEN")
PATIENT_ID=$(echo "$EXISTANTS" | jq -r '.results[0].id // empty')
if [[ -z "$PATIENT_ID" ]]; then
  CREATION=$(api_call POST "/accounts/patients/" 201 \
    '{"nom": "Test", "prenoms": "Utilisateur", "sexe": "F"}' "$TOKEN")
  PATIENT_ID=$(echo "$CREATION" | jq -r '.id')
  info "Profil créé : $PATIENT_ID"
else
  info "Profil existant réutilisé : $PATIENT_ID"
fi

# 4) Recherche d'un établissement et d'un praticien avec créneaux libres ----
info "4/8 Recherche d'un praticien vérifié avec des créneaux libres..."
PRATICIENS=$(api_call GET "/directory/praticiens/" 200 "" "")
EXERCICE_ID=""
ETABLISSEMENT_NOM=""
for id in $(echo "$PRATICIENS" | jq -r '.results[].exercices[]?.id'); do
  CRENEAUX_TEST=$(api_call GET "/scheduling/creneaux/?exercice=${id}&statut=libre" 200 "" "")
  if [[ "$(echo "$CRENEAUX_TEST" | jq '.results | length')" -gt 0 ]]; then
    EXERCICE_ID="$id"
    ETABLISSEMENT_NOM=$(echo "$PRATICIENS" | jq -r --arg id "$id" \
      '.results[].exercices[] | select(.id == $id) | .etablissement_nom')
    break
  fi
done

if [[ -z "$EXERCICE_ID" ]]; then
  error "Aucun exercice avec des créneaux libres trouvé."
  error "seed_demo génère déjà des créneaux sur 14 jours à partir de la date du seed ;"
  error "si vous avez seedé il y a plus de 14 jours, ou si tous les créneaux ont déjà"
  error "été réservés par des tests précédents, régénérez-en avec :"
  error "  venv/bin/python manage.py generer_creneaux"
  exit 1
fi
info "Exercice retenu : $EXERCICE_ID (${ETABLISSEMENT_NOM})"

# 5) Choix d'un créneau libre -------------------------------------------------
info "5/8 Choix d'un créneau libre..."
CRENEAUX=$(api_call GET "/scheduling/creneaux/?exercice=${EXERCICE_ID}&statut=libre" 200 "" "")
CRENEAU_ID=$(echo "$CRENEAUX" | jq -r '.results[0].id')
CRENEAU_DEBUT=$(echo "$CRENEAUX" | jq -r '.results[0].debut')
info "Créneau retenu : $CRENEAU_ID (début : $CRENEAU_DEBUT)"

# 6) Verrouillage (RG-06, 5 minutes) -----------------------------------------
info "6/8 Verrouillage du créneau..."
api_call POST "/scheduling/creneaux/${CRENEAU_ID}/verrouiller/" 200 "" "$TOKEN" > /dev/null

# 7) Confirmation du rendez-vous ----------------------------------------------
info "7/8 Confirmation du rendez-vous..."
RDV=$(api_call POST "/scheduling/rendez-vous/confirmer/" 201 \
  "{\"patient_id\": \"${PATIENT_ID}\", \"creneau_id\": \"${CRENEAU_ID}\", \"exercice_id\": \"${EXERCICE_ID}\", \"motif\": \"Test automatisé\"}" \
  "$TOKEN")
RDV_ID=$(echo "$RDV" | jq -r '.id')
info "Rendez-vous confirmé : $RDV_ID (statut : $(echo "$RDV" | jq -r '.statut'))"

# 8) "Mes rendez-vous" ---------------------------------------------------------
info "8/8 Vérification dans « mes rendez-vous »..."
MES_RDV=$(api_call GET "/scheduling/rendez-vous/mes-rendez-vous/" 200 "" "$TOKEN")
echo "$MES_RDV" | jq '.results[] | {id, statut, motif}'

echo
echo -e "${GREEN}${BOLD}Parcours complet réussi.${NC}"
echo
read -rp "Annuler ce rendez-vous de test maintenant ? [O/n] : " ANNULER
if [[ ! "$ANNULER" =~ ^[nN] ]]; then
  api_call POST "/scheduling/rendez-vous/${RDV_ID}/annuler/" 200 \
    '{"motif": "Fin du test automatisé"}' "$TOKEN" > /dev/null
  info "Rendez-vous annulé, créneau libéré."
fi

#!/usr/bin/env bash
# Lance le serveur de développement de CE projet sur le port 8001 au lieu
# du port 8000 par défaut de Django — pratique si un autre projet occupe
# déjà le 8000 sur votre machine. Passez un autre numéro en argument pour
# changer le port ponctuellement : ./run.sh 8002
set -euo pipefail
cd "$(dirname "$0")"

if [ -d venv ]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

PORT="${1:-8001}"
echo "SantéGuinée backend -> http://127.0.0.1:${PORT}/"
python manage.py runserver "0.0.0.0:${PORT}"

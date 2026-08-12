#!/usr/bin/env bash
set -euo pipefail
cd /var/www/html/PDF2JATS

if [[ ! -x .venv/bin/python ]]; then
  echo "Creando entorno virtual .venv..."
  python3 -m venv .venv
fi

.venv/bin/python -m pip install -q --upgrade pip
.venv/bin/python -m pip install -q -r requirements.txt
.venv/bin/python -m py_compile app.py core/*.py emisores/*.py

sudo systemctl daemon-reload
sudo systemctl restart pdf2jats
sleep 2
curl -fsS http://127.0.0.1:5000/ >/dev/null

echo "OK: PDF2JATS activo."
echo "https://mvillalobosc.diinf.usach.cl/PDF2JATS/?v=110"

#!/usr/bin/env bash
# ============================================================
# Precarga (warmup) del Asistente IA en Ollama.
# Envía el MISMO contexto que usa la app (publicaciones y tesis),
# con keep_alive:-1, para dejar el modelo + contexto cargados en
# RAM. Así, al abrir la app, el asistente ya responde rápido.
#
# Uso:   ./warmup.sh
# Ollama en otro host/puerto:  OLLAMA_URL=http://IP:11434 ./warmup.sh
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

echo "Warmup ResearchAnalyser -> $OLLAMA"
for f in pub_body tesis_body; do
  if [ ! -f "$DIR/$f.json" ]; then echo "  falta $f.json"; continue; fi
  printf "  %-11s " "$f"
  curl -s -o /dev/null -w "HTTP %{http_code}  %{time_total}s\n" \
    "$OLLAMA/api/chat" -H "Content-Type: application/json" \
    --data-binary "@$DIR/$f.json" || echo "curl fallo"
done
echo "Listo. El modelo queda cargado (keep_alive:-1)."

#!/bin/bash
# Executado uma única vez pelo serviço "migrate" do docker-compose.
# Verifica se o banco local está vazio; se sim, importa do Atlas.

set -e

ATLAS_URI="mongodb+srv://pc-trabalho:rYNWsv3wsZWLaYNg@lyria.vrdoy.mongodb.net/Lyria?retryWrites=true&w=majority&appName=Lyria"
LOCAL_URI="mongodb://admin:admin123@mongo:27017/Lyria?authSource=admin"

echo "[migrate] Aguardando MongoDB local ficar disponível..."
until mongosh "$LOCAL_URI" --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 2
done
echo "[migrate] MongoDB local OK."

# Verifica se já existe alguma coleção no banco Lyria
COLLECTIONS=$(mongosh "$LOCAL_URI" --eval "db.getCollectionNames().length" --quiet 2>/dev/null | tail -1)

if [ "$COLLECTIONS" != "0" ] && [ -n "$COLLECTIONS" ]; then
  echo "[migrate] Banco já tem dados ($COLLECTIONS coleções). Pulando migração."
  exit 0
fi

echo "[migrate] Banco local vazio. Iniciando migração do Atlas..."

# Dump do Atlas
DUMP_DIR="/tmp/atlas_dump"
mkdir -p "$DUMP_DIR"

echo "[migrate] Fazendo dump do Atlas..."
mongodump \
  --uri="$ATLAS_URI" \
  --db=Lyria \
  --out="$DUMP_DIR" \
  --quiet

echo "[migrate] Dump concluído. Restaurando no MongoDB local..."

mongorestore \
  --uri="$LOCAL_URI" \
  --db=Lyria \
  "$DUMP_DIR/Lyria" \
  --drop \
  --quiet

echo "[migrate] ✅ Migração concluída com sucesso!"

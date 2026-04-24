#!/bin/bash
# ============================================================
# Migração: MongoDB Atlas → MongoDB local (Docker)
# Execute este script na raiz do servidor (onde está docker-compose.yml)
# ============================================================

set -e

ATLAS_URI="mongodb+srv://pc-trabalho:rYNWsv3wsZWLaYNg@lyria.vrdoy.mongodb.net/Lyria?retryWrites=true&w=majority&appName=Lyria"
LOCAL_URI="mongodb://admin:admin123@127.0.0.1:27017/Lyria?authSource=admin"
DUMP_DIR="$(pwd)/mongo_dump"

echo "=============================="
echo " MIGRAÇÃO ATLAS → LOCAL"
echo "=============================="

# 1. Garantir que o MongoDB local esteja rodando
echo ""
echo "[1/4] Subindo MongoDB local..."
docker compose up -d mongo
echo "    Aguardando MongoDB ficar pronto..."
sleep 5

# 2. Dump do Atlas
echo ""
echo "[2/4] Fazendo dump do Atlas (banco: Lyria)..."
mkdir -p "$DUMP_DIR"

docker run --rm \
  --network host \
  -v "$DUMP_DIR":/dump \
  mongo:7 \
  mongodump \
    --uri="$ATLAS_URI" \
    --db=Lyria \
    --out=/dump

echo "    Dump concluído em: $DUMP_DIR/Lyria"

# 3. Restore para MongoDB local
echo ""
echo "[3/4] Restaurando dados no MongoDB local..."

docker run --rm \
  --network host \
  -v "$DUMP_DIR":/dump \
  mongo:7 \
  mongorestore \
    --uri="$LOCAL_URI" \
    --db=Lyria \
    /dump/Lyria \
    --drop

echo "    Restore concluído!"

# 4. Subir o servidor completo
echo ""
echo "[4/4] Subindo o servidor completo..."
docker compose up -d

echo ""
echo "=============================="
echo " MIGRAÇÃO CONCLUÍDA!"
echo " Banco de dados local ativo."
echo " Servidor rodando em :9000"
echo "=============================="
echo ""
echo "Para acompanhar os logs:"
echo "  docker compose logs -f server"

#!/bin/bash
# Executado pelo serviço "migrate" do docker-compose.
# 1. Se o banco estiver vazio, importa do Atlas.
# 2. Sempre imprime um relatório do banco ao final.

set -e

ATLAS_URI="mongodb+srv://pc-trabalho:rYNWsv3wsZWLaYNg@lyria.vrdoy.mongodb.net/Lyria?retryWrites=true&w=majority&appName=Lyria"
LOCAL_URI="mongodb://admin:admin123@mongo:27017/Lyria?authSource=admin"

print_report() {
  echo ""
  echo "============================================"
  echo " RELATÓRIO DO BANCO (MongoDB local)"
  echo "============================================"
  mongosh "$LOCAL_URI" --quiet --eval "
    const cols = db.getCollectionNames();
    cols.forEach(c => {
      const count = db.getCollection(c).countDocuments();
      print('  ' + c.padEnd(20) + count + ' documentos');
    });
    print('');
    print('  Total de coleções: ' + cols.length);
  " 2>/dev/null
  echo "============================================"
  echo ""
}

echo "[migrate] Aguardando MongoDB local ficar disponível..."
until mongosh "$LOCAL_URI" --eval "db.adminCommand('ping')" --quiet > /dev/null 2>&1; do
  sleep 2
done
echo "[migrate] MongoDB local OK."

# Verifica se já existe alguma coleção no banco Lyria
COLLECTIONS=$(mongosh "$LOCAL_URI" --eval "db.getCollectionNames().length" --quiet 2>/dev/null | tail -1)

if [ "$COLLECTIONS" != "0" ] && [ -n "$COLLECTIONS" ]; then
  echo "[migrate] Banco já tem dados. Pulando migração."
  print_report
  exit 0
fi

echo "[migrate] Banco local vazio. Iniciando migração do Atlas..."

# Dump do Atlas
DUMP_DIR="/tmp/atlas_dump"
mkdir -p "$DUMP_DIR"

echo "[migrate] Fazendo dump do Atlas (isso pode levar alguns minutos)..."
if ! mongodump \
  --uri="$ATLAS_URI" \
  --db=Lyria \
  --out="$DUMP_DIR" \
  --quiet; then
  echo "[migrate] ❌ ERRO: Falha ao conectar ou exportar do Atlas."
  echo "[migrate]    Verifique se o cluster Atlas ainda está acessível."
  echo "[migrate]    O banco local continuará vazio — o servidor pode falhar."
  exit 1
fi

echo "[migrate] Dump concluído. Restaurando no MongoDB local..."

mongorestore \
  --uri="$LOCAL_URI" \
  --db=Lyria \
  "$DUMP_DIR/Lyria" \
  --drop \
  --quiet

echo "[migrate] ✅ Migração concluída!"
print_report

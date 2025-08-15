#!/bin/bash

echo "🚀 Iniciando deploy do Personal Finance..."

cd ~/PersonalFinance

if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Há mudanças não commitadas. Faça commit ou stash antes do deploy."
    exit 1
fi

CURRENT_HASH=$(git rev-parse HEAD)

echo "📥 Verificando mudanças no repositório..."
git fetch origin main

REMOTE_HASH=$(git rev-parse origin/main)

if [[ "$CURRENT_HASH" == "$REMOTE_HASH" ]]; then
    echo "✅ Nenhuma mudança encontrada. Deploy não necessário."
    exit 0
fi

echo "📥 Encontradas novas mudanças. Atualizando..."
git pull origin main

if [[ $? -ne 0 ]]; then
    echo "❌ Erro ao puxar mudanças do git"
    exit 1
fi

echo "⏸️  Parando containers..."
docker compose down

echo "🧹 Limpando imagens antigas..."
docker image prune -f

echo "🔨 Rebuilding e iniciando containers..."
docker compose build --no-cache
docker compose up -d

sleep 5

echo "📊 Status dos containers:"
docker compose ps

echo "🔍 Testando aplicação..."
if curl -f -s http://192.168.0.14:4001 > /dev/null; then
    echo "✅ Deploy realizado com sucesso!"
    echo "🌐 Aplicação disponível em: http://192.168.0.14:4001"
else
    echo "❌ Aplicação não está respondendo"
    echo "📝 Logs da aplicação:"
    docker compose logs web --tail=20
fi

echo "🏁 Deploy finalizado!"

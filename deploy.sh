#!/bin/bash

SKIP_GIT_CHECK=false

while [[ "$1" != "" ]]; do
    case "$1" in
        --skip-git)
            SKIP_GIT_CHECK=true
            ;;
    esac
    shift
done

echo "🚀 Iniciando deploy do Personal Finance..."

cd ~/PersonalFinance

if [ "$SKIP_GIT_CHECK" = false ]; then
    if [[ -n $(git status --porcelain) ]]; then
        echo "❌ Há mudanças não commitadas. Use --skip-git para forçar."
        exit 1
    fi

    echo "📥 Atualizando repositório..."
    git fetch origin main
    git pull origin main || { echo "❌ Erro ao puxar mudanças do git"; exit 1; }
else
    echo "⚠️  Pulando verificação e atualização do git. Deploy continuará mesmo com mudanças locais."
fi

echo "⏸️  Parando containers..."
docker compose down web

echo "🧹 Limpando imagens antigas..."
docker image prune -f web

echo "🔨 Rebuilding e iniciando containers..."
DOCKER_BUILDKIT=1 docker compose build web
docker compose up -d web

sleep 5

echo "📊 Status dos containers:"
docker compose ps

echo "🔍 Testando aplicação..."
if curl -f -s http://192.168.0.14:4001 > /dev/null; then
    echo "✅ Deploy realizado com sucesso!"
else
    echo "❌ Aplicação não está respondendo"
    docker compose logs web --tail=20
fi

echo "🏁 Deploy finalizado!"


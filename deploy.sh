#!/bin/bash

echo "🚀 Iniciando deploy do Personal Finance..."

# Ir para o diretório do projeto
cd ~/PersonalFinance

# Verificar se há mudanças locais não commitadas
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Há mudanças não commitadas. Faça commit ou stash antes do deploy."
    exit 1
fi

# Puxar as mudanças do git
echo "📥 Puxando mudanças do repositório..."
git pull origin main

# Verificar se houve mudanças
if [[ $? -ne 0 ]]; then
    echo "❌ Erro ao puxar mudanças do git"
    exit 1
fi

# Parar containers existentes
echo "⏸️  Parando containers..."
docker-compose down

# Limpar imagens antigas (opcional)
echo "🧹 Limpando imagens antigas..."
docker image prune -f

# Rebuild e subir
echo "🔨 Rebuilding e iniciando containers..."
docker-compose up -d --build

# Aguardar um pouco para garantir que subiu
sleep 5

# Verificar status
echo "📊 Status dos containers:"
docker-compose ps

# Testar se está funcionando
echo "🔍 Testando aplicação..."
if curl -f -s http://192.168.0.14:4001 > /dev/null; then
    echo "✅ Deploy realizado com sucesso!"
    echo "🌐 Aplicação disponível em: http://192.168.0.14:4001"
else
    echo "❌ Aplicação não está respondendo"
    echo "📝 Logs da aplicação:"
    docker-compose logs web --tail=20
fi

echo "🏁 Deploy finalizado!"

# Seção de Renda Fixa

## Fase 1: Fundação da Renda Fixa (MVP)

- 1.1 Modelo de Dados para Renda Fixa:
    - Tabela FixedIncomeInvestment:
        - name: Nome do ativo (e.g., "CDB Banco XP")
        - institution: Banco/Corretora
        - type: (e.g., :cdb, :lci, :lca, :lc, :tesouro_selic)
        - usar um Ecto.Enum ou string)
        - start_date: Data de aplicação
        - maturity_date: Data de vencimento
        - remuneration_rate: String (e.g., "110%", "12%")
        - remuneration_basis: (:CDI, :a_a)
        - liquidity_date: Data de carência/resgate
        - is_tax_exempt: Booleano
        - initial_invested_value: Valor total aplicado inicialmente
        - profile_id
        - ledger_id

    - Migração FixedIncomeTransaction: Tabela para registrar cada aporte/resgate/juros de um investimento específico:
        - fixed_income_investment_id,
        - type: (:deposit, :withdrawal, :interest_payment, etc.)
        - value,
        - date,
        - general_transaction_id: FK OPCIONAL para a tabela Transaction (para vincular a movimentação de RF à transação geral gerada).

    - Modificar Transaction (se necessário): Adicionar uma coluna fixed_income_transaction_id (nullable) para criar a ligação.

- 1.2 Funcionalidade de Gerenciamento de Investimentos de Renda Fixa:
    - Seção Dedicada "Renda Fixa" :
        - Tabela listando todos os FixedIncomeInvestment do usuário/perfil.
        - CRUD de FixedIncomeInvestment:
            - Formulário para criar/editar um investimento de Renda Fixa.
        - Geração Automática de Transação Geral no Aporte:
            - Ao salvar um novo FixedIncomeInvestment (ou um novo aporte a um existente), criar uma Transaction do tipo :expense com a categoria "Investimento" e o valor do aporte.
            - (Opcional): Vincular a nova Transaction à FixedIncomeTransaction e vice-versa.
        - Aporte/Resgate em Investimentos Existentes:
            - Interface para registrar um novo aporte (que incrementa o initial_invested_value do FixedIncomeInvestment e gera uma FixedIncomeTransaction).
            - Interface para registrar um resgate (que decrementa o initial_invested_value / current_value e gera uma FixedIncomeTransaction).
        - Geração Automática de Transação Geral no Resgate: - Ao registrar um resgate de um FixedIncomeInvestment, criar uma Transaction do tipo :income com uma categoria "Rendimentos de Investimento" (ou similar) e o valor do resgate. - (Opcional): Vincular a nova Transaction à FixedIncomeTransaction.

- 1.3 Integração de Dados e Cálculos (CDI):
    - Integração com API de CDI:
        - Serviço para buscar o CDI diário/acumulado (e.g., do Banco Central via API ou scraping).
        - Job em Background: Um Oban ou GenServer.start_link para buscar e armazenar o CDI diariamente.
    - Cálculo de current_value:
        - Função para calcular o valor atual (current_value) de um FixedIncomeInvestment baseado na remuneration_rate e no CDI acumulado desde a start_date.
        - Exibir current_value na tabela de investimentos de Renda Fixa.
    - Métricas Básicas:
        - Growth (Crescimento): current_value - initial_invested_value.
        - Total Value: current_value.

---

## Fase 2: Refinamento e Métricas Avançadas (Futuro)

- 2.1 Métricas e Projeções de Rentabilidade:
    - Cálculo de Rentabilidade Bruta (%) e Líquida (%).
    - Estimativa de IR a Pagar (com base na tabela regressiva de IR para RF).
    - Cálculo de IOF (se resgate antes de 30 dias).
    - Projeção de Valor no Vencimento.

- 2.2 Visualização Aprimorada:
    - Gráfico de Evolução do current_value de um investimento específico.
    - Gráfico de Evolução do Total Investido em Renda Fixa no Dashboard Principal.

- 2.3 Notificações e Alertas:
    - Notificações para Vencimentos Próximos.
    - Notificações para Fim de Carência/IOF.

- 2.4 Organização e Segmentação (Conforme seu Comentário):
    - Agrupamento de FixedIncomeInvestment por "Objetivo" (e.g., "Reserva de Emergência", "Aposentadoria") - Pode ser uma nova tabela/tag.
    - Tags Personalizadas para investimentos.

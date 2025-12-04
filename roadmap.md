# Personal Finance — Auditoria de Módulos e Evolução

## 1. Panorama Atual por Diretório

### 1.1 Raiz de Domínio (`lib/personal_finance.ex`)
- Função de fachada para orquestrar contexts (`accounts`, `finance`, `investment`, `balance`), fornecendo aliases centralizados usados por controllers e LiveViews.
- Ideal para expor operações compostas (ex.: criação de ledger completo) e manter camada anti-corrupção entre Web e domínios.

### 1.2 Aplicação & Infraestruturas
| Arquivo | Observações |
| --- | --- |
| `personal_finance/application.ex` | Supervisiona Telemetry, Repo, migrator, Oban, DNSCluster, PubSub e Endpoint. Não há children para PriceCache, ForecastServer ou RuleEngine, indicando lacunas. |
| `personal_finance/repo.ex` | Config padrão Ecto; ausência de telemetria customizada ou query instrumentation para auditoria além do básico. |
| `personal_finance/mailer.ex` | Provê interface Swoosh; focado em fluxo de auth (reset/convite/admin), sem notificações financeiras. |
| `personal_finance/release.ex` | Tarefas de migração/rollback/seed para ambiente release; sem rotinas de bootstrap de dados de domínio (ex.: import default categories por ledger). |
| `personal_finance/balance.ex` | Delega cálculos agregados (saldo por ledger/profile). Atualmente limitado a somas básicas de `transactions`; não cobre FI/ações nem previsões. |

### 1.3 Contexto Accounts (`personal_finance/accounts*.ex`)
- `accounts.ex`: Funções de autenticação, recuperação de senha, criação de primeiro admin, criação de usuários pelo admin, sudo mode e helpers de sessão. Não controla escopo de ledger diretamente.
- `accounts/user.ex`: Schema de usuário com campos padrão (email, hashed_password, role, authenticated_at, confirmed_at). Não possui ainda preferências financeiras (ex.: `preferred_currency`, `preferred_locale`).
- `accounts/user_token.ex`: Tokens para sessão, confirmações e resets; inexistência de tokens para Open Finance consent ou integrações externas.
- `accounts/user_notifier.ex`: Templates de email de confirmação/reset; não há notificações sobre eventos financeiros.
- `accounts/scope.ex`: Define struct de escopo (`Scope`) usada extensivamente em Finance/Investment e Web para carregar usuário atual, ledger e demais filtros; ainda não incorpora roles por ledger.

### 1.4 Contexto Finance
| Arquivo | Função Atual | Lacunas |
| --- | --- | --- |
| `finance.ex` | Context façade rico: CRUD para ledgers, perfis, categorias, transações, recorrências e colaboradores de ledger; agrega filtros, paginação e alguns cálculos auxiliares. | Falta consolidar consultas mensais/anuais e validações cross-entity (limites e soma de percentuais). |
| `finance/ledger.ex` | Schema `ledgers` com `owner_user_id` e campos básicos de identificação. Falta auditoria (`origin_user_id`), campos de configuração (moeda base, metas) e flags de comportamento. |
| `finance/ledger_users.ex` | Mapeia relacionamentos usuário ↔ ledger; permite compartilhamento, mas sem coluna `role`/permissões detalhadas. |
| `finance/profile.ex` | Perfis (nome, ledger_id, `is_default`, descrição). Não há campos para metas, limites mensais, tags ou cor. |
| `finance/category.ex` | Campos `name`, `type`, `is_default`, `is_fixed`, `percentage`, `is_investment`; cobre categorias padrão e personalizadas. Faltam validações globais (soma de percentuais <= 100%) e indicadores derivados (ex.: taxa de poupança). |
| `finance/investment_type.ex` | Enum auxiliar para tipificar investimentos ligados a transações; hoje utilizado principalmente para FI. |
| `finance/transaction.ex` | Transações de income/expense com `amount`, `value`, `total_value`, `type`, `profile_id`, `category_id`, `investment_type_id` e filtros robustos no contexto. Ainda não suporta tipo explícito `transfer` nem integrações com ações. |
| `finance/recurring_entry.ex` | Define transações recorrentes com frequência; há validações de frequência/tipo, mas não existe um engine dedicado para geração automática e acompanhamento de instâncias. |
| `balance.ex` | Consolida somatórios por ledger/profile a partir de `transactions`; não integra FI/ações, sem caching. |

### 1.5 Contexto Investment
| Arquivo | Papel |
| --- | --- |
| `investment.ex` | Contexto de investimentos focado em renda fixa: lista/cria/atualiza FI, orquestra `FixedIncomeTransaction`, calcula e atualiza `current_balance`, gera transações gerais no ledger e faz broadcast para LiveViews. Ainda sem referência a ações. |
| `investment/fixed_income.ex` | Schema de ativos de renda fixa com `initial_investment`, `current_balance`, `start_date`, `end_date`, flags de atividade, totais de rendimento e imposto. Implementa validations fortes e é atualizado automaticamente via `update_balance/2`. |
| `investment/fixed_income_transaction.ex` | Registra depósitos, saques e yields; campos `type`, `value`, `date`, impostos e relação opcional com `transaction` geral. Já atualiza saldo de FI e cria transações no ledger via `Investment.create_transaction/4`. |
| `investment/market_rate.ex` | Armazena taxas externas (ex.: CDI) consumidas em cálculos de FI; alimentado por workers, mas ainda sem camadas de histórico analítico ou normalização por múltiplas fontes. |

### 1.6 Utils (`personal_finance/utils/*.ex`)
- `currency_utils.ex`: Formatadores/parsers monetários; falta suporte a múltiplas moedas ou arredondamentos configuráveis.
- `date_utils.ex`: Helpers para períodos e timezone; não inclui calendário de mercado/feriados.
- `parse_utils.ex`: Converte strings para números/datas; útil para importações, mas sem validação robusta de CSV/OFX.

### 1.7 Workers (`personal_finance/workers/*.ex`)
- `market_rates_worker.ex`: Periodicamente busca taxas (CDI/IPCA). Não armazena histórico longo nem expõe interface de assinatura.
- `yields_worker.ex`: Atualiza rendimentos FI. Não publica eventos para Forecast/Timeline.

### 1.8 Camada Web (`personal_finance_web/*`)
- **Endpoint/Router**: Estrutura Phoenix padrão, rotas autenticadas com `user_auth`. Sem API pública JSON para terceiros.
- **Components**: `core_components`, `infinite_scroll`, `tab_panel`, layouts; atende dashboards existentes.
- **Controllers**: Apenas `transaction_controller` (provável REST interno) e auth; falta controllers para FI, stocks, forecasts, timeline.
- **LiveViews**:
  - `home/index`: Dashboard atual limitado a saldo e transações recentes.
  - `transaction/*`: CRUD manual e importação simplificada (CSV).
  - `fixed_income/*`: Gestão completa de FI (cards, detalhes, operações).
  - `category/*`, `ledgers/*`, `settings/*`: Configurações e perfis.
  - `user/*`, `admin/*`: Setup e administração de usuários.
  - Ausentes: timeline unificada, ações, forecasts, alertas, ferramentas de cálculo.

## 2. Avaliação de Cobertura vs. Especificação

| Feature | Status Atual | Gap Principal |
| --- | --- | --- |
| Ledger & Perfis | ✅ CRUD básico | Falta auditoria, limites, metas. |
| Categorias c/ tipos | ✅ | Não há limite percentual nem regras. |
| Transações (income/expense) | ✅ | Sem transfer, fixed-income ops, stock ops, total_value. |
| Fixed Income completo | 🟡 | Reset automático, integração ledger, forecast pendentes. |
| Variable Income (ações) | ❌ | Nenhum schema/serviço/UI. |
| Forecast Engine (FI, FIRE, CAGR) | ❌ | Só cálculos pontuais em `balance`. |
| Timeline consolidada | ❌ | Somente listagem de transações manuais. |
| Analytics (histórico 12m, categorias) | ❌ | Sem consultas ou telas dedicadas. |
| Open Finance import | ❌ | Falta tabelas `import_jobs`, pipeline, dedupe. |
| RuleEngine / Alertas | ❌ | Não existe serviço dedicado. |
| PriceCache GenServer | ❌ | Workers atuais apenas taxas FI. |
| Ferramentas de cálculo diário | ❌ | Não há módulo/UI para simulações. |

## 3. Modelo de Cálculo de Saldos, Orçamento e Investimentos

### 3.1 Visões principais

- **Saldo de caixa (cash)**  
  - Considera apenas `transactions` com `type: :income` ou `:expense`.  
  - FI e ações entram no caixa **apenas** via transações de aporte (expense) e resgate (income).  
  - Não lê diretamente `fixed_income.current_balance` nem valor de ações.

- **Patrimônio financeiro**  
  - Definido como:  
    - `patrimonio = saldo_caixa + soma(FI.current_balance) + soma(valor_mercado_acoes)`  
  - Usado para visão de longo prazo (evolução de riqueza), separado do orçamento mensal.

- **Orçamento do mês**  
  - Trabalha apenas com `transactions` do período:  
    - Receitas (`type: :income`).  
    - Despesas (`type: :expense`), incluindo aportes em FI (categoria Investimentos).  
  - Patrimônio (FI/ações) não entra diretamente aqui, apenas via essas transações.

### 3.2 Renda Fixa (FI) no fluxo de caixa

- **Aportes em FI**  
  - Criam um `fixed_income_transaction` com `type: :deposit`.  
  - Disparam uma `transaction` geral com:  
    - `type: :expense`.  
    - `category`: Investimentos (ou similar).  
  - Efeitos:  
    - Caixa diminui.  
    - `fixed_income.current_balance` aumenta.  
    - Orçamento registra gasto em Investimentos (permite saber se a meta de aporte do mês foi cumprida).

- **Rendimentos e resgates de FI**  
  - Enquanto não há resgate, o rendimento permanece dentro de FI, apenas ajustando `current_balance` (patrimônio cresce, caixa não muda).  
  - No resgate:  
    - `fixed_income_transaction` `type: :withdraw` (e opcionalmente `:yield` para separar principal/juros).  
    - `transaction` geral com:  
      - `type: :income`.  
      - `category`: Rendimentos de Investimentos.  
    - Caixa aumenta e orçamento registra renda correspondente.

### 3.3 Percentuais e metas por categoria

- **Base de renda para orçamento**  
  - Usa `transactions` de `type: :income` na categoria "Sem categoria" como base mensal de renda para o budget.  
  - `renda_base_mes = soma(incomes em "Sem categoria" no mês)`.

- **Meta por categoria**  
  - Cada categoria de despesa tem um campo `percentage`.  
  - A meta de valor para a categoria X em um mês é:  
    - `meta_X = renda_base_mes * percentage_X / 100`.  
  - Exemplo:  
    - 3 incomes de R$ 1.000 em "Sem categoria" → `renda_base_mes = 3.000`.  
    - Categoria Investimentos com `percentage = 30` → `meta = 900`.

- **Uso da meta e alertas**  
  - Para cada categoria X, calcula-se:  
    - `gasto_real_X = soma(expenses da categoria X no mês)`.  
    - `%_usado_X = gasto_real_X / meta_X * 100`.  
  - A partir de `%_usado_X` surgem alertas simples (ex.: > 80% atenção, > 100% estourou a meta).

### 3.4 Indicadores e Health Score (versão simples)

- **Savings rate mensal (esboço)**  
  - `renda_base_mes = soma(incomes em "Sem categoria")`.  
  - `gasto_consumo_mes = soma(expenses em categorias não marcadas como Investimentos)`.  
  - `aportes_FI_mes = soma(expenses na categoria Investimentos)`.  
  - Savings aproximado:  
    - `savings = renda_base_mes − gasto_consumo_mes − aportes_FI_mes`.  
  - Savings rate: `savings / renda_base_mes` (quando `renda_base_mes > 0`).

- **Qualidade de meses**  
  - Um mês pode ser considerado "bom" quando:  
    - Gastos em categorias críticas ficaram ≤ meta.  
    - E o savings rate ficou acima de um limiar (ex.: 10–20%).  
  - O health score pode incorporar **% de meses bons** nos últimos 12 meses.

- **Crescimento de patrimônio**  
  - Usando snapshots mensais:  
    - `patrimonio_mes = caixa_mes + FI_mes (+ ações_mes)`.  
  - Indicadores:  
    - Crescimento absoluto e percentual nos últimos 12 meses.  
    - Comparação de gastos do mês atual vs mês anterior por categoria chave.

## 3. Recomendações de Evolução

### 3.1 Camada de Domínio
1. **Auditoria Global**: adicionar campos (`origin_user_id`, `inserted_at`, `updated_at`) para ledger, profiles, categories, transactions, FI, trades, permitindo entender quem criou/alterou entidades importantes ao longo do tempo.
2. **Regras Embutidas Simples**: em vez de um `RuleEngine` OTP completo, implementar regras pontuais diretamente em `Finance`/`Balance` (ex.: impedir exclusão de categorias críticas, avisar quando gasto ultrapassa limite, destacar FI com saldo inesperado), usando flash messages, event log e, no futuro, pequenos cards de alerta.
3. **LedgerAudit (Opcional / OSS Futuro)**: deixar documentada a ideia de uma tabela de auditoria mais rica (com inconsistências detectadas automaticamente e painel admin), mas tratá-la como algo a ser explorado apenas se o projeto OSS ganhar mais usuários.

### 3.2 Fixed Income
1. **Integração Contábil**: cada depósito/saque gera transação ledger (expense/income) via multi Ecto, mantendo FI e transações gerais sempre sincronizadas.
2. **Atualização Automática de Saldo**: jobs/rotinas que recalculam `current_balance` quando necessário, reaproveitando funções já existentes em `Investment` (sem exigir um servidor de forecast dedicado).
3. **Extrato & Timeline**: visão unificada de operações de FI junto com transações comuns, usada principalmente em LiveViews de histórico e detalhes.

### 3.3 Variable Income (Stocks)
1. **Schemas Essenciais**: `stocks` (ativo), `stock_positions` (posição consolidada) e `stock_trades` (trades individuais) focados em buy & hold, dividendos e crescimento, sem complexidade de rebalanceamento.
2. **Cálculos e Métricas Simples**: módulo `Stocks.Analysis` para preço médio, valor de mercado, yield on cost e outras métricas relevantes para buy & hold; IR detalhado pode continuar sendo tratado fora do sistema.
3. **Visualização e Notas de Posição**: LiveViews para ver carteira consolidada, posições individuais, histórico de trades e anotações sobre cada ativo (motivo de investimento, tese, horizonte, etc.). PriceCache e rebalance engine ficam como ideias de OSS futuro, não prioridade.

### 3.4 Forecast & Analytics
1. **Forecast Functions**: módulo matemático (`Utils.Math`) com funções puras de FV, CAGR, FIRE, projeções de carteira e médias móveis, reutilizado por telas de simulação (playground) e por cards simples no dashboard. Não há necessidade de um serviço OTP separado, apenas funções de cálculo.
2. **Timeline LiveView**: visão unificada em LiveView combinando transações, FI ops e, futuramente, trades de ações, com filtros e paginação. A API REST fica como algo opcional para o futuro do projeto OSS, não como requisito atual.
3. **Monthly Analytics**: consultas otimizadas (ou materializadas via snapshots) para gastos por categoria, comparativo multi-mês e previsão simples de renda/expense (média móvel 6m), usadas diretamente em dashboards.
4. **Dashboard Consolidado**: cards de patrimônio total, FI, renda variável (quando existir), saldo mensal, alertas básicos (limites de categorias, por exemplo) e pequenos forecasts derivados das funções matemáticas.

### 3.5 Open Finance & Importações
1. **Import Jobs**: tabela `import_jobs` com estados e payloads; processados por Oban, focados inicialmente em fontes específicas que você realmente usa (ex.: sincronizar Mercado Pago, bancos que não exportam CSV com facilidade).
2. **Pipeline de Importação Simples**: etapas Normalize → Match → Dedup → Persist reaproveitando `ParseUtils` e regras leves de categorização; objetivo principal é reduzir o trabalho manual de lançamento, especialmente para quem não está animado em registrar tudo na mão.
3. **Integração Open Finance Focada**: em vez de um consent management completo, manter o foco em conexões práticas (ex.: job que consome uma API ou export alternativo do Mercado Pago e gera `transactions`), deixando autenticação OAuth/consent detalhado como possibilidade futura se o projeto OSS ganhar tração.

### 3.6 Ferramentas de Uso Diário
1. **Finance Math Toolkit (`PersonalFinance.Utils.Math`)**:
  - Juros compostos (FV discreto/contínuo), conversão de taxas.
  - Simulador de aportes recorrentes.
  - Calculadora de preço médio de ações e métricas simples.
  - SMA/Média móvel para previsão de renda vs despesa.
2. **LiveView “Calculadoras” / Playground**: UI dedicada para simulações (FV, aportes, FIRE, métricas de ações), usando apenas funções puras de cálculo e sem persistência, servindo como laboratório pessoal.
3. **CLI & Mix Tasks**: comandos rápidos para simulações e importações (ex.: `mix pf.calc fv --amount 1000 --rate 0.13 --years 5`).

### 3.7 Observabilidade & DX
- Adicionar Telemetry events em transações, FI ops e workers.
- Criar testes de integração para pipelines (importação, forecast).
- Documentar APIs e fluxos (Markdown + OpenAPI) mantendo alinhamento com especificação.

## 4. Próximos Passos
1. Estabelecer auditoria básica no banco (campos de quem criou/alterou) antes de novas features mais críticas.
2. Priorizar toolkit de cálculos, playground e melhorias de importação (especialmente o fluxo que reduz lançamentos manuais).
3. Evoluir Fixed Income e snapshots/históricos para garantir que o sistema conte bem a "história" financeira ao longo dos anos.
4. Introduzir, de forma incremental, visualização de ações voltada a buy & hold (posições, métricas simples, notas).
5. Tratar Open Finance como integração focada em fontes específicas (ex.: Mercado Pago), mantendo o restante do desenho como possibilidade para o futuro OSS.

## 5. Timeline Unificada
- **Objetivo**: apresentar em uma única visão cronológica todas as movimentações relevantes (transações comuns, operações de renda fixa, trades de ações, importações Open Finance e alertas).
- **Implementação sugerida**:
  - View materializada ou consulta parametrizada agregando dados por `date`/`inserted_at`, normalizando para estrutura `[%TimelineEntry{}]`.
  - API `GET /api/ledgers/:id/timeline?from=...&to=...&type=...`.
  - LiveView com filtros (tipo, categoria, perfil), suporte a infinite scroll e exportação.
  - Integração com Forecast/RuleEngine para destacar eventos previstos ou alertas.
- **Benefícios**: auditoria, storytelling financeiro, facilidade de debugging de importações automatizadas.

## 6. RuleEngine Detalhado
- **Propósito**: centralizar regras dinâmicas que disparam alertas, bloqueios ou ações automatizadas.
- **Design**:
  - Processo OTP (`PersonalFinance.RuleEngine`) supervisionado, consumindo eventos (Oban, PubSub).
  - Cada regra implementa `c:Rule.evaluate/2` recebendo contexto (ledger, perfil, snapshot financeiro).
  - Exemplos de regras: limite percentual de categoria estourado, saldo de FI negativo, perfil sem transações há X dias, divergência entre saldo esperado e real.
  - Output padronizado (`%RuleResult{severity, message, metadata}`) persistido em `ledger_alerts` e exibido no dashboard/timeline.
- **Extensibilidade**: DSL simples para adicionar novas regras e parametrizá-las por ledger/perfil sem alterar código central.

## 7. Projeto de Testes Automatizados
- **Estrutura**:
  - `test/support` com `DataCase`, `ConnCase` e `LiveViewCase` básicos.
  - Suites focadas em:
    - **Domain**: testes de changesets e serviços principais (Finance, Investment, funções de cálculo em `Utils.Math`).
    - **LiveView/Controllers**: testes de interação para telas críticas (transações, FI, importação).
    - **Workers**: testes simples de Oban `perform/1` para jobs de import/snapshots.
  - CI opcional rodando `mix test` e checagens leves de formato/credo.
- **Objetivo**: ter testes diretos o suficiente para garantir que novas features não quebrem comportamentos antigos, sem sobrecarregar o projeto com infra de testes "enterprise".

## 8. Refatoração de Contextos e Padronização
- Separar responsabilidades:
  - `PersonalFinance.Ledgers` (ledger + permissões + audit).
  - `PersonalFinance.Budgeting` (categorias, limites, alertas).
  - `PersonalFinance.Cashflow` (transações, recurring entries, timeline base).
  - `PersonalFinance.Investments.FixedIncome` / `.Stocks`.
- Padronizar convenções:
  - Todos os contexts expõem funções `list_*`, `get_*!(id)`, `create_*`, `update_*`, `delete_*`, `change_*`.
  - Uso consistente de `multi` para operações compostas.
  - Serviços auxiliares (RuleEngine, Forecast) recebem structs puros e retornam `{:ok, result}` / `{:error, reason}`.
- Documentar dependências entre contexts para evitar acoplamentos circulares.

## 9. Controle de Permissões para Ledgers Compartilhados (OSS Futuro)
- Para o uso atual (poucos usuários conhecidos), o fluxo de admin existente é suficiente.
- Caso o projeto OSS ganhe mais usuários no futuro, pode ser interessante:
  - Estender `Finance.LedgersUsers` com coluna `role` (`owner`, `editor`, `viewer`).
  - Adicionar políticas de permissão em plugs/socket.
  - Disponibilizar UI para gestão de convites e escopos.

## 10. Ajustes e Melhorias Adicionais
- Revisar forms LiveView incompletos (`ProfilesPanel`, `TransactionForm`, etc.) para garantir `update/2`, `handle_event/3` e mensagens de validação consistentes.
- Consolidar componentes de UI repetidos (ex.: cards de saldo) em `core_components`.
- Habilitar telemetria detalhada no Repo e workers para alimentar futuros dashboards de auditoria.
- Adotar configurações padrão (credo, dialyzer, formatter) compartilhadas via `.formatter.exs` e `config/*.exs`.

## 11. Ideias de Features Futuras
- **Health Score do Ledger**: índice de saúde financeira (0–100) por ledger/perfil, calculado a partir de savings rate, uso de limites de categoria, regularidade de aportes em FI e ausência de dívidas. Exposto como card no dashboard e série histórica mensal.
- **Simulador de "What-if"**: cenários hipotéticos sobre o histórico real (ex.: aumentar aportes em FI, cortar percentual de despesas em uma categoria), usando o mesmo motor do `ForecastEngine` sem persistir alterações no banco.
- **Objetivos Financeiros (Goals)**: metas nomeadas ligando perfis + posições de FI (ex.: reserva de emergência, aposentadoria), com barra de progresso, data estimada de conclusão (baseada em `MarketRate` + `Utils.Math`) e integração com alertas.
- **Tagging Semântico de Transações**: além de categorias, permitir tags (livres ou pré-definidas) para análises horizontais (“Viagem Europa 2026”, “Reforma Casa”), com tela de "Projetos" mostrando custo total, linha do tempo e fontes de financiamento.
- **Recomendações Automáticas de Budget**: após 3–6 meses de uso, sugerir novos limites percentuais por categoria com base no comportamento real (ex.: notificar quando o gasto recorrente está sistematicamente acima/abaixo do limite configurado).
- **Modo Empresa/Contabilidade Simples**: flag no ledger para tratá-lo como PJ (campos extras como CNPJ, descrição do negócio) e relatórios específicos (DRE simplificada, fluxo de caixa direto), reaproveitando o motor de transações/categorias.

## 12. Pequenas Melhorias de Alto Impacto
- **Preferências por Usuário**: adicionar em `accounts/user.ex` campos como `preferred_locale` e `preferred_currency`, integrando com `LocaleHook` e `CurrencyUtils` para definir idioma e moeda padrão por usuário, sem depender apenas de sessão/front.
- **Sugestão Automática de Categoria**: ao digitar a descrição da transação, sugerir categoria com base em histórico (combinação de `description` + `category_id`), gravando pequenas regras de auto-completar para acelerar lançamentos recorrentes.
- **Perfis com Cor**: garantir bom uso do campo `color` em `finance/profile.ex` para diferenciar visualmente perfis (Pessoal, Família, Empresa) em cards, filtros e gráficos.
- **Rascunho de Transação**: flag simples de "draft" em `transactions` para permitir anotar lançamentos rápidos (especialmente em mobile) e revisá-los/confirmá-los depois em um painel de pendências.
- **Quick Actions no Dashboard**: área fixa com botões de atalho ("+ Renda Fixa", "+ Despesa recorrente", "+ Transferência"), reaproveitando os forms e LiveViews existentes para reduzir fricção no uso diário.
- **Filtros Salvos de Transações**: permitir salvar combinações frequentes de filtros (datas, categorias, perfis, tipos) como "views" nomeadas, exibidas na UI como atalhos.
- **Notas Rápidas por Ledger/Perfil**: campos de anotação livre em `ledger` e `profile` (ex.: "Este mês foco em reduzir restaurante"), exibidos no topo das telas relacionadas para contextualizar decisões.

## 13. Funcionalidades de Dificuldade Média
- **Categorias com Limite Mensal e Percentual Usado**: estender `finance/category.ex` com campo opcional `monthly_limit` (ou derivá-lo a partir de renda x `percentage`) e criar funções em `Finance` para calcular, por mês, o total gasto por categoria e a razão `gasto / limite`. Na UI, exibir barras de progresso por categoria (com cores em 80% / 100%) e permitir navegar para o histórico mensal de uso de cada categoria.
- **Histórico de Alterações de Budget/Categorias**: criar tabela `category_changes` (ou `budget_history`) contendo `category_id`, `old_percentage`, `new_percentage`, `changed_by_user_id`, `changed_at` e, opcionalmente, `old_monthly_limit`/`new_monthly_limit`. Toda vez que uma categoria tiver limite/percentual alterado, registrar uma entrada. Disponibilizar uma aba "Histórico" na tela de categorias para auditoria e entendimento de como o orçamento evoluiu.
- **Snapshots Mensais de Saldo e Patrimônio**: job mensal (Oban) que calcula e persiste, por ledger/perfil, o saldo em caixa (a partir de `transactions`), o saldo consolidado de renda fixa (`fixed_income.current_balance`) e, futuramente, de ações. Esses snapshots permitem gráficos leves de evolução de patrimônio no `home/index` e em telas de analytics, evitando consultas pesadas on-the-fly.
- **Import Wizard com Fila de Transações Não Mapeadas**: evoluir o fluxo atual de importação de CSV para uma tela (ou modal lateral amplo) em múltiplos passos: (1) upload + preview, (2) mapeamento de colunas (data, descrição, valor, categoria opcional), (3) lista de transações que não conseguiram ser categorizadas automaticamente. Nessa lista, o usuário escolhe categorias diretamente em uma tabela editável, e só então as transações são persistidas. Opcionalmente, as escolhas podem alimentar regras simples para melhorar futuras sugestões automáticas de categoria.

## 14. Laboratório e UX Avançada (Longo Prazo)
- **Perfis Sazonais**: permitir marcar perfis como ativos apenas em determinados meses (ex.: "IPTU", "Matrícula Escolar"). Novos campos em `finance/profile.ex` (`is_seasonal`, `active_months`) controlam visibilidade padrão na UI. No mês correspondente, o sistema destaca o perfil e pode exibir lembretes específicos ("Lembrar de registrar IPTU"), mantendo a interface mais limpa no restante do ano.
- **Reservas Vinculadas a Renda Fixa (Goals por Ativo)**: introduzir um pequeno contexto de `goals` que liga objetivos ("Reserva de Emergência", "Aposentadoria") diretamente a posições de FI. Cada goal tem `target_amount` e se associa a um ou mais `fixed_incomes`; o sistema calcula `saldo_atual / alvo` como progresso. A principal função é visual: mostrar claramente que certo CDB/Tesouro está "casado" com uma reserva específica.
- **Checklist Mensal**: card no `home/index` com uma lista enxuta de tarefas recorrentes ("Registrar salário", "Revisar limites de categoria", "Conferir FI", etc.). Um registro `monthly_checklists` por ledger/ano/mês guarda quais itens foram concluídos. Ajuda a criar um ritual mensal de revisão, sem ser intrusivo.
- **Modo Foco por Usuário**: flag simples em `accounts/user.ex` (ex.: `focus_mode`) para esconder seções avançadas (FI, forecasts, analytics, admin) da navegação. Na prática, permite que apenas quem se interessa por todos os recursos veja tudo, enquanto outro usuário (ex.: cônjuge) enxerga uma interface mais simples focada em lançamentos e visão geral.
- **Event Log Interno Leve**: uma tabela genérica `events` para registrar eventos de domínio relevantes (ledger criado, FI aberta/fechada, import executado, alteração de limite de categoria). Cada evento guarda `ledger_id`, `type`, `message` e `metadata` (json). Uma LiveView de "Event Log" por ledger facilita debugging e auditoria pessoal quando algo parecer estranho no saldo.
- **Playground de Funções Matemáticas e Simulações**: tela dedicada (ex.: `PlaygroundLive`) que expõe funções de `Utils.Math` e de forecast em formulários interativos para simulações de juros compostos, aportes mensais, curva de FI, cenários simples de FIRE, etc. Nada é persistido; é apenas uma UI de experimentação usando as mesmas fórmulas que o sistema utiliza "de verdade" nas demais telas.
- **Feature Flags Simples**: mecanismo leve para ativar/desativar grandes blocos de funcionalidade (ex.: ações, forecast avançado, playground) via configuração (`config :personal_finance, :features, ...`) e helpers (ex.: `PersonalFinance.Features.enabled?(:playground)`). Útil para experimentar features novas em ambiente pessoal sem precisar mexer em rotas/código toda vez.

## 15. Roadmap (Próximos ~6 Meses)

### 15.1 Ordem Sugerida (mais simples → mais complexa)

1. **Notas rápidas por ledger/perfil**  
   - Tipo: bem simples.  
   - Esforço: ~1–2 dias de trabalho leve.  
  - Tarefas: adicionar campo `notes` em `ledger`/`profile`, mostrar/editar nos forms e nas telas principais, exibir resumo em `home/index` e nas listas de perfis, e criar notas mensais por ledger (`ledger_month_notes`) com edição direta via card no dashboard.

2. **Perfis com cor**  
  - Tipo: simples, focado em UX.  
  - Esforço: ~2 dias.  
  - Tarefas: campo `color` em `finance/profile.ex` (e usos na UI), ajustes nos cards/listas e filtros.

3. **Preferências por usuário (moeda/idioma)**  
   - Tipo: simples, mexe em Accounts + Web.  
   - Esforço: ~2–3 dias.  
   - Tarefas: campos `preferred_locale`/`preferred_currency` em `accounts/user.ex`, integração leve com `LocaleHook` e `CurrencyUtils`.

4. **Rascunho de transação**  
   - Tipo: simples/médio.  
   - Esforço: ~3–4 dias.  
   - Tarefas: flag `draft` em `transactions`, filtro/aba de "pendentes" e ações de confirmar/descartar.

5. **Quick actions no dashboard**  
   - Tipo: simples/médio.  
   - Esforço: ~2–3 dias.  
   - Tarefas: componentes de botão fixo chamando os forms existentes (transação, FI, recorrente).

6. **Math Toolkit (`Utils.Math`) + Playground v1**  
   - Tipo: médio, isolado (baixo risco).  
   - Esforço: ~1–2 semanas.  
   - Tarefas: criar módulo com funções de FV, aportes, conversão de taxa, PM de ação; criar `PlaygroundLive` com 2–3 formulários de simulação.

7. **Sugestão automática de categoria por descrição**  
   - Tipo: médio.  
   - Esforço: ~1–2 semanas.  
   - Tarefas: guardar pares (descrição normalizada → categoria) conforme o uso, sugerir no form e permitir aceitar/ignorar.

8. **Categorias com limite mensal + % usado**  
   - Tipo: médio.  
   - Esforço: ~2 semanas.  
   - Tarefas: campo `monthly_limit`, funções em `Finance` para somar gastos do mês, barras de progresso na UI.

9. **Histórico de alterações de budget/categorias**  
   - Tipo: médio.  
   - Esforço: ~1–2 semanas.  
   - Tarefas: tabela `category_changes`, hooks ao atualizar limite/percentual, aba de "Histórico" em categorias.

10. **Snapshots mensais de saldo/patrimônio**  
  - Tipo: médio/avançado.  
  - Esforço: ~2–3 semanas.  
  - Tarefas: tabela de snapshots, job Oban mensal, gráficos simples de evolução no dashboard.

11. **Import Wizard v1 (tela em vez de modal)**  
  - Tipo: médio/avançado.  
  - Esforço: ~3–4 semanas.  
  - Tarefas: nova LiveView para importação, preview de CSV, lista de linhas não mapeadas com seleção de categoria, integração com fluxo atual.

12. **Event log interno leve**  
  - Tipo: médio.  
  - Esforço: ~2 semanas.  
  - Tarefas: tabela `events`, helpers `log_event/3`, tela simples por ledger para inspeção.

13. **Checklist mensal**  
  - Tipo: médio.  
  - Esforço: ~1–2 semanas.  
  - Tarefas: definir itens fixos de checklist, tabela `monthly_checklists`, card no `home/index` com marcação de concluído.

14. **Modo foco por usuário**  
  - Tipo: médio.  
  - Esforço: ~1 semana.  
  - Tarefas: flag em `User`, ajustes em `Layouts` e sidebar para esconder seções avançadas.

15. **Visualização básica de ações (buy & hold)**  
  - Tipo: médio/avançado.  
  - Esforço: ~3–5 semanas.  
  - Tarefas: schemas `stocks`, `stock_positions`, `stock_trades`, funções de PM/valor/metrics simples, LiveViews de carteira e posição com notas.

16. **Perfis sazonais**  
  - Tipo: médio.  
  - Esforço: ~1–2 semanas.  
  - Tarefas: campos `is_seasonal`/`active_months` em `profile`, filtros por mês atual e lembretes específicos.

17. **Reservas (Goals) vinculadas a FI**  
  - Tipo: médio/avançado.  
  - Esforço: ~3–4 semanas.  
  - Tarefas: context pequeno de `goals`, junção com `fixed_incomes`, cards de progresso por objetivo.

18. **Open Finance focado (ex.: Mercado Pago)**  
  - Tipo: avançado.  
  - Esforço: altamente variável (estimativa inicial ~4–8 semanas dependendo da API).  
  - Tarefas: estudar formas de integração (API oficial, gambiarras de exportação), criar `import_jobs` específicos, pipeline Normalize → Match → Persist.

19. **Health Score simples por ledger/perfil**  
  - Tipo: avançado mas incremental.  
  - Esforço: ~2–4 semanas.  
  - Tarefas: definir fórmula simples (ex.: savings rate, consistência de aportes, uso de limites), calcular periodicamente ou on-the-fly com apoio de snapshots, exibir em cards.

### 15.2 Distribuição em ~6 Meses (estimativa)

Considerando 3–4 horas por dia útil + 6–7h em fins de semana, algo como 20–25h/semana:

- **Mês 1–2**  
  - Passo zero: revisar e alinhar regras de cálculo de saldo, percentuais de categoria, inclusão/exclusão de FI/ações no saldo consolidado e demais fórmulas já existentes (especialmente em `Balance`, `Finance.Transaction`, `Investment` e qualquer agregação usada no dashboard). Documentar as decisões no próprio `features.md` para servir de referência.  
  - Em seguida, itens 1–6: notas, cor/ícone, preferências de usuário, rascunho de transação, quick actions e Math Toolkit + Playground v1.

- **Mês 3–4**  
  - Itens 7–10: sugestão de categoria, limites mensais + % usado, histórico de categorias e snapshots mensais básicos.

- **Mês 5–6**  
  - Itens 11–14: Import Wizard v1, event log leve, checklist mensal e modo foco.  
  - Se sobrar tempo/ânimo, começar 15 (visualização de ações) ou 17 (Goals vinculados a FI).

Itens 16–19 podem ser encaixados conforme motivação e necessidade real, sem pressão — o importante é manter o sistema saudável e útil pra você no dia a dia.
# 🚀 Case Study: Estoque Luxpryme — Sistema Industrial Multiplataforma (Flutter & Supabase) com Arquitetura Local-First Zero-Latency

**Autor:** Tomas Pereyra  
**Papel no Projeto:** Arquiteto de Software, Product Owner & Administrador do Sistema  
**Empresa:** Luxpryme Indústria Eletrônica  
**Versão Atual:** 1.5.0  
**Stack Tecnológica:** Flutter 3, Dart, Supabase Cloud, PostgreSQL, Local-First Engine, JSON Storage, Streams Reativos, Engenharia de Software Assistida por IA  
**Plataformas:** Windows Desktop & Android Mobile (Smartphones e Coletores)  

---

## 📌 Resumo Executivo

O **Estoque Luxpryme** é uma solução corporativa completa de controle de estoque e almoxarifado industrial, concebida, arquitetada e gerida por mim para atender a rotina de alta precisão da **Luxpryme Indústria Eletrônica**.

Combinando minha base de conhecimento em programação com **Arquitetura de Software, Engenharia de Requisitos Industriais e Direção Técnica de IA Agentiva**, liderei toda a concepção do sistema — definindo regras de negócio fabris, estrutura de dados, fluxos de experiência do usuário (UX) em bancada, decisões de sincronização Local-First e validação contínua — sem precisar digitar manualmente o código-fonte linha a linha.

O software gerencia um catálogo técnico de **mais de 5.420 componentes**, integrando desde as bancadas do laboratório de engenharia eletrônica (microcomponentes SMD, semicondutores, placas PTH e PCBs) até as linhas fabris de montagem de luminárias industriais, preparação e almoxarifado geral.

---

## 🏭 1. O Desafio Industrial

Em um ambiente real de manufatura eletrônica, a agilidade operacional e a confiabilidade dos saldos de estoque são fatores críticos. Os principais problemas do chão de fábrica que mapeei e resolvi na arquitetura foram:

1. **Volume e Especificidade Técnica do Inventário:** Mais de 5.420 produtos com nomenclaturas técnicas extensas, códigos internos, *part numbers* de fabricantes globais, múltiplas formas de medição (unidades, peso em `kg`/`g`, comprimento em `m`/`cm`, volume em `L`/`mL`) e localizações físicas em gaveteiros e prateleiras.
2. **Ambiente com Instabilidade de Rede:** Galpões fabris sofrem com zonas de sombra de Wi-Fi. Um aplicativo que dependesse de chamadas HTTP síncronas travaria os operadores a cada oscilação de sinal.
3. **Necessidade de Zero Latência na Bancada:** O operador não pode esperar 3 a 5 segundos em uma tela de carregamento a cada componente que retira, edita ou adiciona ao carrinho. A resposta precisava ser instantânea (**0ms**).
4. **Estoques Compartilhados vs Estoques Físicos Separados por Setor:** Alguns insumos ficam armazenados em um único local e são compartilhados por múltiplos setores, enquanto outros possuem **estoques físicos separados em setores diferentes** (ex: um lote no laboratório de *Eletrônica* e outro lote separado na linha de *Produção*), exigindo visão individual por setor e soma consolidada na visão geral da fábrica.
5. **Governança e Rastreabilidade por Operador:** Operadores de um setor não devem alterar insumos restritos de outra área sem autorização. Era indispensável um controle de alçadas rápido por PIN numérico individual de 4 dígitos, sem a fricção de logins longos.

---

## 🏛️ 2. Arquitetura da Solução

Para responder a esses requisitos, defini uma arquitetura **Local-First (Offline-First) com Latência Zero (0ms)** e sincronização assíncrona desacoplada em nuvem via Supabase.

```
┌────────────────────────────────────────────────────────┐
│                   INTERFACE (UI)                       │
│        Desktop (Windows)  |  Mobile (Android)          │
│       • Resposta em 0ms   • Reatividade por Streams    │
└───────────────────────────┬────────────────────────────┘
                            │
               ┌────────────┴────────────┐
               │                         │
               ▼                         ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│     MEMÓRIA LOCAL       │    │     CACHE EM DISCO      │
│   Listas em RAM (0ms)   │    │  Persistência Imediata  │
│  Validação Instantânea  │    │ (local_products_cache)  │
└──────────────┬──────────┘    └─────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────┐
│        WORKER DE SINCRONIZAÇÃO EM SEGUNDO PLANO        │
│        (Disparado de forma Assíncrona / unawaited)     │
└──────────────┬─────────────────────────┬───────────────┘
               │ (Online)                │ (Offline / Falha)
               ▼                         ▼
┌─────────────────────────┐    ┌─────────────────────────┐
│      SUPABASE CLOUD     │    │   FILA DE CONTINGÊNCIA  │
│ PostgreSQL / Realtime   │    │ (pending_sync_queue)    │
│ Reconciliação de UUID   │    │ Auto-flush ao Conectar  │
└─────────────────────────┘    └─────────────────────────┘
```

### Pilares Arquiteturais Definidos:
* **Frontend Multiplataforma:** Flutter & Dart — compilação nativa de alto desempenho para Windows Desktop e Android Mobile a partir de uma arquitetura unificada.
* **Backend & Persistência Cloud:** Supabase Cloud (PostgreSQL 15) com sincronização multi-tabela (`products`, `categories`, `master_categories`, `operator_pins`, `stock_movements`).
* **Persistência Local-First:** Camada `LocalCacheService` em disco (JSON) combinada com estado reativo em RAM (`StreamController<List<T>>`), garantindo abertura do app em **0 segundos** mesmo sem internet.

---

## ⚡ 3. Decisões de Arquitetura e Soluções Projetadas

### 3.1. Mutação Local em 0ms e Sincronização em Segundo Plano
Em vez de bloquear a interface aguardando a resposta da nuvem:
* Todas as ações (cadastro, edição, duplicação de estoque, arquivamento, ajustes `+1/-1`, troca de categorias em lote e baixa de carrinho) atualizam **primeiro a memória RAM e o cache em disco local em 0ms**.
* O envio ao Supabase ocorre de forma 100% assíncrona em segundo plano, com fila de contingência offline (`pending_sync_queue.json`) e sincronização manual completa multi-tabela (`syncAllWithSupabase`).

### 3.2. Modelagem Híbrida de Setores: Estoque Compartilhado vs Duplicação de Estoque
Projetei um modelo flexível que atende as duas realidades físicas da fábrica:
* **Estoque Compartilhado:** Quando um item é armazenado em um único ponto mas usado por mais de um setor, o mesmo registro vincula múltiplos setores.
* **Estoques Separados por Setor (`Duplicar estoque`):** Permite criar um segundo estoque independente do mesmo produto em outro setor. Na aba de cada setor o operador vê e movimenta apenas o saldo daquele setor, enquanto na aba **`Todas`** (e no relatório geral) o sistema consolida automaticamente os registros em **1 único card** com a **soma total dos estoques** e o detalhamento por setor.

### 3.3. Motor de Busca com Espera Inteligente (*Debounce*) e Ranqueamento de Relevância `O(N)`
Para pesquisar em mais de 5.420 produtos com fluidez total:
* **Espera de Digitação (*Debounce*):** A barra de pesquisa aguarda o usuário terminar de escrever (ou pressionar `Enter`) antes de disparar a filtragem, eliminando travamentos durante a digitação.
* **Algoritmo de Melhor Coincidência (`O(N)`):** Calcula a pontuação de relevância uma única vez por item, priorizando no topo correspondências exatas da frase, pares de palavras consecutivas, códigos internos e validação por limite exato de palavra para siglas técnicas curtas (`AC`, `DC`, `IR`, `UV`), ignorando acentos automaticamente.

### 3.4. Unidades de Medida Configuráveis e Persistência Zero-Migration
* Cada produto pode ser configurado para contagem por **Unidade (`un`)**, **Peso (`kg` / `g`)**, **Metro (`m` / `cm`)** ou **Volume (`L` / `mL`)**.
* A arquitetura serializa metadados estendidos (como unidade de medida e estado de arquivamento) de forma transparente sobre a estrutura existente do PostgreSQL, mantendo compatibilidade total com a nuvem sem exigir migrações destrutivas de banco.

### 3.5. Operações em Lote de Alta Produtividade (`+ Carrinho`, `+ Itens`, `- Itens` e Troca de Categorias)
Projetei fluxos específicos para eliminar cliques repetitivos no dia a dia:
* **`+ Carrinho (Adicionar Produtos)`:** Permite buscar e selecionar vários produtos em sequência informando a quantidade diretamente em um campo à direita de cada item.
* **Preservação Inteligente de Posição:** Ao selecionar um componente no `+ Carrinho`, `+ Itens`, `- Itens` ou `Trocar Categoria de Produtos`, o texto buscado é limpo automaticamente para a próxima pesquisa, mas a lista permanece na exata posição onde o usuário estava até que ele volte a digitar.

### 3.6. Produtos Arquivados, Lixeira de Recuperação e Relatórios Diretos em PDF/CSV
* **Seção `Arquivados`:** Isola produtos fora de uso que ainda possuem saldo físico em estoque, mantendo-os divididos por setor e totalmente editáveis.
* **Lixeira de Produtos:** Protege contra exclusões acidentais permitindo restauração imediata com PIN.
* **Exportação Direta de Relatórios (PDF A4 e CSV Excel):** Geração de inventários de setores ativos, produtos arquivados e histórico de movimentações ordenados por **Código Interno** ou **Alfabético por Nome**, com salvamento direto em arquivo `.pdf` (janela *"Salvar como..."* no Windows e compartilhamento nativo no Android) ou impressão.

---

## 📊 4. Resultados e Métricas de Impacto

* **Catálogo Industrial Ativo:** Mais de 5.420 produtos geridos com resposta instantânea.
* **Latência de Interface nas Bancadas:** Reduzida de ~3 segundos para **0 milissegundos**.
* **Validação de Credenciais por PIN:** Reduzida de ~1.500ms para **< 0,01ms** com atribuição exata por funcionário no histórico.
* **Disponibilidade Operacional:** **100% funcional offline e online**, imune a oscilações de Wi-Fi no galpão industrial.
* **Qualidade Verificada:** **51 testes automatizados** validando busca por relevância, duplicação e soma de estoques, unidades de medida, arquivados, relatórios, categorias por setor, RBAC e resolução de conflitos.

---

## 👨‍💻 5. Sobre o Autor e Arquiteto do Projeto

**Tomas Pereyra**  
**Arquiteto de Software, Product Owner & Administrador do Sistema Estoque Luxpryme.**  
Responsável pela visão do produto, levantamento de requisitos no chão de fábrica, arquitetura Local-First, modelagem de fluxos operacionais, direção técnica de implementação assistida por IA, testes de aceitação e administração da infraestrutura multiplataforma (Windows e Android).

* **GitHub:** [github.com/tomi-pereyra/luxpryme-stock](https://github.com/tomi-pereyra/luxpryme-stock)
* **Competências Destacadas:** Arquitetura de Software, Engenharia de Requisitos, Sistemas Local-First / Offline-First, Gestão de Produto Industrial, Engenharia de Software Assistida por IA (Flutter, Dart, Supabase, PostgreSQL).

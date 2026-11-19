<div align="center">
  <img src="assets/icon/app_icon.png" width="128" height="128" alt="Logo Estoque Luxpryme" style="border-radius: 24px;" />
  <h1>Estoque Luxpryme</h1>
  <p><strong>Sistema Industrial de Controle de Almoxarifado e Estoque de Alta Precisão</strong></p>
  <p>
    <b>Versão 1.3.0</b> • <b>Local-First Zero-Latency (0ms)</b> • <b>100% Offline-First</b> • <b>Setores Industriais</b> • <b>Rastreabilidade por PIN</b>
  </p>
  <p>
    Desenvolvido e Administrado por <b>Tomas Pereyra</b> para <b>Luxpryme Indústria Eletrônica</b>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Plataformas-Windows%20%7C%20Android-blue?style=flat-square" alt="Plataformas" />
    <img src="https://img.shields.io/badge/Flutter-3.47+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Backend-Supabase%20Cloud-3ECF8E?style=flat-square&logo=supabase&logoColor=white" alt="Supabase" />
    <img src="https://img.shields.io/badge/Testes-36%20Aprovados-brightgreen?style=flat-square" alt="Testes" />
    <img src="https://img.shields.io/badge/Licen%C3%A7a-Propriet%C3%A1ria-red?style=flat-square" alt="Licença" />
  </p>
</div>

---

## 🎨 Identidade Visual Corporativa

O **Estoque Luxpryme** adota uma identidade visual sóbria, funcional e moderna, desenhada especificamente para ambientes industriais, galpões fabris e laboratórios eletrônicos:

* **Símbolo Oficial:** Quadrado com cantos arredondados em **Azul Luxpryme** (`#1976D2`) destacando a letra **"L"** em **branco puro** com proporção geométrica harmoniosa e excelente legibilidade.
* **Paleta de Cores Setorial:**
  * 🔵 **Azul Luxpryme (`#1976D2`):** Setor de Laboratório Eletrônico (SMD, PTH, PCBs, ICs) e cor mestra do sistema.
  * 🟢 **Verde Produção (`#16A34A`):** Setor de Produção Industrial (montagem mecânica, chicotes, baterias e luminárias).
  * ⚪ **Cinza Slate (`#64748B`):** Setor Outros (almoxarifado geral, manutenção fabril, civil e insumos de apoio).
  * 🟣 **Cores Customizadas:** Novos setores criados pela supervisão podem receber cores exclusivas (ex: Roxo para *Embalamento*, Laranja para *Preparação*).
* **Feedback de Estoque:**
  * 🟢 **Verde (`#16A34A`):** Estoque Saudável / Normal.
  * 🟡 **Âmbar (`#D97706`):** Estoque Baixo (próximo ao ponto de pedido).
  * 🔴 **Vermelho (`#DC2626`):** Estoque Esgotado / Alerta de Saldo Negativo.
* **Tipografia:** Família *Inter* para interface de alta densidade e *Montserrat* no símbolo corporativo.

---

## 🏭 Arquitetura por Setores da Fábrica

Para suportar grandes volumes e evitar interferências entre áreas produtivas, o estoque é estruturado em **Setores**:

```mermaid
flowchart TD
    A["PIN Mestre (Supervisor Geral)"] --> B["Acesso a Todos os Setores"]
    A --> C["Gestão de Setores Dinâmicos"]
    A --> D["Gestão em Lote (+ Itens / - Itens)"]
    A --> E["Resolução de Conflitos de Saldo Negativo"]
    
    F["PIN Setorial de Eletrônica"] --> G["Movimenta apenas itens de Eletrônica"]
    H["PIN Setorial de Produção"] --> I["Movimenta apenas itens de Produção"]
    J["PIN Setorial Customizado"] --> K["Movimenta apenas itens do seu Setor"]
```

* **Multi-Vínculo:** Um produto pode pertencer a mais de um setor simultaneamente (ex: um chicote ou bateria usado tanto no laboratório eletrônico quanto na linha de montagem final).
* **Setores Dinâmicos:** Novos setores industriais (ex: *Preparação de Fios*, *Embalamento*, *Expedição*) podem ser criados a qualquer momento pelo supervisor com PIN Mestre diretamente pelo app.

---

## 🚀 Principais Recursos da Versão 1.3.0

### 1. Arquitetura Local-First Zero-Latency (0ms)
* **Resposta Imediata na Interface:** Todas as operações de cadastrar novo item, editar produto, exclusão, ajuste unitário (+1/-1) ou finalização de carrinho acontecem **instantaneamente na memória e no cache local** em **0 milissegundos**.
* **Zero Telas de Espera:** Diálogos e formulários fecham de imediato sem exibir *loading spinners* ou travar o operador.
* **Sincronização Desacoplada em Segundo Plano:** O envio de dados para o Supabase (PostgreSQL) é executado em tarefas assíncronas em segundo plano.
* **Reconciliação Automática de UUID:** Ao cadastrar produtos, o sistema usa identificadores locais imediatos e reconcilia o UUID oficial gerado pelo PostgreSQL silenciosamente assim que o banco confirma.
* **Validação Instantânea de PIN (0,001ms):** Autenticação realizada diretamente no cache em memória, eliminando a espera de rede a cada autorização.

### 2. Tecnologia 100% Offline-First
* **Baixa Única em Disco:** O catálogo completo (> 5.420 produtos) é gravado no armazenamento local do aparelho.
* **Abertura em 0s:** Ao reabrir o aplicativo, o catálogo inicializa instantaneamente sem depender de conexão com a internet.
* **Fila de Sincronização Pendente:** Alterações feitas sem Wi-Fi são gravadas localmente e enviadas automaticamente para a nuvem assim que a internet retornar.

### 3. Detecção e Resolução de Conflitos de Estoque
* Se dispositivos retirarem peças de um mesmo componente enquanto desconectados e o saldo resultante ficar negativo ao sincronizar, o sistema emite um alerta destacado com 4 opções de regularização:
  1. **Zerar Saldo (0 un)** com registro de auditoria.
  2. **Digitar Saldo Real** contado fisicamente na prateleira/gaveteiro.
  3. **Estornar Déficit** devolvendo as peças ao ponto de equilíbrio.
  4. **Dispensar Notificação**.

### 4. Gestão em Lote de Setores (`+ Itens` e `- Itens`)
* **`+ Itens`:** Ferramenta com busca inteligente e contador dinâmico (círculo azul) para adicionar múltiplos produtos a um setor. A busca limpa automaticamente o campo a cada seleção enquanto a lista permanece congelada na exata posição onde o item foi clicado, só mudando quando o usuário volta a digitar.
* **`- Itens`:** Filtra apenas os itens do setor para desvincular em lote com segurança e a mesma rolagem preservada.

### 5. Lixeira de Produtos (Recuperação Segura Anti-Exclusão)
* Exclusões de produtos não são destrutivas: itens excluídos são movidos com segurança para a **Lixeira de Produtos**.
* Permite pesquisar e **Restaurar** qualquer item de volta ao estoque ativo com 1 clique (e autorização por PIN), preservando intactos todos os códigos, setores e quantidades anteriores.
* Disponível tanto no menu flutuante inferior direito quanto no botão de lixeira no cabeçalho superior.

### 6. Carrinho de Separação com Observação Técnica
* Separação de kits de componentes para ordens de produção ou entrada de notas de fornecedores.
* Suporta **anotação opcional** direta no carrinho (ex: *"OS #840 - Linha 2 de Luminárias"*).
* Baixa conjunta protegida por autenticação de **PIN de 4 dígitos**.

### 7. Histórico com Agrupamento Inteligente no Mesmo Momento
* Movimentações unitárias rápidas (`+` e `-`) feitas em sequência no mesmo momento pelo mesmo operador são consolidadas automaticamente em um único **cartão expansível**.
* Evita poluição visual de dezenas de linhas individuais, permitindo expandir ("Ver todos") para auditar cada componente com horário e saldo resultante.
* Exportação completa para planilhas CSV com um clique.

### 8. Busca Multi-Termo Desordenada
* Localiza qualquer produto mesmo se as palavras forem digitadas fora de ordem (ex: `farol placa 16` encontra `MONTAGEM PLACA ELETRONICA FAROL 16 LEDS`).
* Busca instantânea por Código Interno e Part Number do Fabricante.

### 9. Interface Adaptativa (Mobile vs Desktop)
* **Mobile (Android):** Menu superior limpo com busca expansível via lupa, barra de setores compacta, acesso às famílias técnicas via toque longo no chip do setor e menu circular de ações flutuante no canto inferior direito.
* **Desktop (Windows):** Barra de busca ampla centralizada, atalhos de administração no cabeçalho e menu de ferramentas rápidas.

---

## 💻 Stack Tecnológica

| Camada | Tecnologia | Detalhes |
| :--- | :--- | :--- |
| **Frontend** | Flutter 3.47+ / Dart 3 | Suporte nativo multiplataforma (Windows Desktop e Android) |
| **Arquitetura** | Local-First Zero-Latency | Operações em 0ms na memória/disco + background workers |
| **Banco de Dados Cloud** | Supabase (PostgreSQL 15) | Regras RLS, triggers de integridade, UUIDs nativos e canais Realtime |
| **Cache Local** | LocalCacheService (Disco) | Armazenamento JSON local persistente e fila offline |
| **Tipografia** | Google Fonts (Inter / Montserrat) | Ergonomia visual de alta densidade de dados |
| **Testes Automatizados** | Flutter Test (38 testes) | Validação de regras de negócio, busca, RBAC, lixeira e agrupamento |

---

## 📚 Documentação e Recursos

* 📘 **[Manual de Uso Completo (Markdown)](./MANUAL_DE_USO.md):** Guia detalhado passo a passo de todas as telas e operações do sistema.
* 📑 **[Manual de Uso Oficial em Word (.docx)](./Manual_de_Uso_Estoque_Luxpryme.docx):** Versão formatada pronta para impressão e distribuição aos operadores.
* 🚀 **[Estudo de Caso Técnico / LinkedIn](./CASE_STUDY_LINKEDIN.md):** Case study de engenharia de software com desafios, decisões arquiteturais e métricas de impacto.

---

## 📦 Como Compilar e Exportar

### 🤖 Gerar APK para Android
```bash
flutter build apk --release
```
* O arquivo final gerado estará em:
  `build/app/outputs/flutter-apk/app-release.apk`

### 💻 Gerar Executável para Windows
```bash
flutter build windows --release
```
* O executável nativo e as DLLs estarão em:
  `build/windows/x64/runner/Release/luxpryme_stock.exe`

---

## 👥 Autoria e Administração

* **Desenvolvedor e Administrador Geral:** Tomas Pereyra (`tomibr20@gmail.com`)
* **Empresa:** Luxpryme Indústria Eletrônica

---

## 📄 Licença

Este software é distribuído sob licença **Proprietária e Confidencial**. Todos os direitos reservados à **Tomas Pereyra** e **Luxpryme Indústria Eletrônica**. Consulte o arquivo [LICENSE](./LICENSE) para obter detalhes completos sobre os termos de uso.

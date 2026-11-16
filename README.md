# 🔷 Estoque Luxpryme

Aplicativo de **Controle de Estoque Industrial** minimalista, robusto e com **sincronização em tempo real**, desenvolvido sob medida para a **Luxpryme** no setor de indústria e manufatura eletrônica.

Disponível para **Android (.apk)** e **Windows (.exe)**.

---

## 🎨 Identidade Visual
* **Logotipo:** Letra **"L"** estilizada em Azul Médio (`#1976D2`) sobre fundo branco puro.
* **Tema:** Material 3 industrial com tipografia moderna (Inter / Roboto Mono para Part Numbers).
* **Feedback de Estoque:** Badges e contadores dinâmicos (Verde = Normal, Âmbar = Estoque Baixo, Vermelho = Esgotado).

---

## 🏷️ Categorias Especializadas da Indústria Eletrônica
1. **Componentes SMD** (Resistores, Capacitores, Diodos, CIs de montagem superficial)
2. **Componentes PTH** (Conectores, Bornes, Capacitores Eletrolíticos, Terminais passantes)
3. **Baterias Industriais** (VRLA Chumbo-Ácido, Packs Li-Ion 18650, NiMH, moedas CR2032)
4. **Placas de Circuito Impresso (PCBs)** (Circuitos impressos / PCIs virgens sem montagem)
5. **Placas com Componentes SMD** (Montadas após processo pick-and-place e forno de refusão)
6. **Placas com Componentes PTH** (Montagem manual, cadinho de onda e kits)
7. **Placas Eletrônicas Testadas** (Gravadas, montadas completas e testadas funcionalmente)
8. **Insumos de Solda e Químicos** (Barras de estanho 63/37, fluxos spray e pastas de solda)
* *Suporte a múltiplas categorias por produto, permitindo filtros cruzados e categorização avançada.*

---

## ⚙️ Principais Funcionalidades
* **Ajuste Rápido Instantâneo (±1):** Permite incrementar ou decrementar uma unidade diretamente no card do produto de forma rápida e instantânea, sem necessidade de senha ou confirmação.
* **Carrinho de Separação de Múltiplos Itens:** Para retiradas ou adições em lote de diversos componentes, os itens são colocados no carrinho com suas respectivas quantidades e finalizados conjuntamente mediante confirmação de um **PIN de 4 dígitos**.
* **Painel Administrativo (Exclusivo Windows):** Tela restrita na versão desktop para cadastrar, ativar, desativar e gerenciar os PINs autorizados dos operadores de fábrica.
* **Busca Inteligente Multi-Critério:** Localização em tempo real por **Nome do Produto**, **Código Interno** ou **Part Number do Fabricante**.
* **Histórico e Relatórios de Movimentação:** Histórico completo com filtros por categoria, período e quantidade, além de exportação de relatório detalhado em **CSV**.

---

## ⚡ Stack Tecnológica (100% Gratuita)
* **Frontend:** Flutter 3.47+ / Dart 3 com suporte a Android e Desktop Windows.
* **Backend & Database:** [Supabase](https://supabase.com) (Plano Free Tier vitalício).
  * **Banco:** PostgreSQL com integridade referencial e validação `CHECK (quantity >= 0)`.
  * **Realtime:** WebSockets nativos via PostgreSQL Replication.
  * **Autenticação Fechada:** Supabase Auth (E-mail e Senha) com registro público desabilitado.

---

## 🚀 Como Iniciar o Projeto do Zero

### 1. Criar o Projeto Gratuito no Supabase
1. Acesse [supabase.com](https://supabase.com) e crie uma conta gratuita (não requer cartão de crédito).
2. Clique em **"New Project"**, defina o nome (ex: `luxpryme-stock`), uma senha forte para o banco de dados e a região mais próxima (ex: *São Paulo - sa-east-1*).
3. No menu lateral esquerdo, vá em **SQL Editor**.
4. Abra o arquivo [`supabase_schema.sql`](./supabase_schema.sql) deste projeto, copie todo o seu conteúdo, cole no SQL Editor do Supabase e clique em **"Run"**.
   * *O script criará a estrutura das tabelas, triggers, políticas de segurança RLS e publicação Realtime.*
5. O cadastro e sincronização dos produtos pode ser realizado diretamente através da interface do aplicativo ou via inserção no banco de dados.

> 💡 **Nota:** O aplicativo permite cadastrar e gerenciar produtos, registrar movimentações e simular separações tanto no Android quanto no Windows.

### 2. Cadastrar Usuários Manualmente (Acesso Restrito)
Como o app possui política de acesso fechada (sem auto-cadastro público):
1. No painel do Supabase, clique em **Authentication** > **Users**.
2. Clique no botão **"Add user"** > **"Create user"**.
3. Preencha o e-mail do operador/gestor (ex: `operador@luxpryme.com`) e a senha de acesso.
4. Marque a opção **"Auto Confirm User"** para que a conta já fique ativa sem depender de e-mail de confirmação.
5. Em **Authentication** > **Providers** > **Email**, você pode desmarcar a opção *"Enable Signups"* para garantir que ninguém consiga se cadastrar por conta própria.

### 3. Conectar o App ao Supabase
Você tem duas opções fáceis:
* **Opção A (Recomendada no Código):** Abra [`lib/core/constants/app_constants.dart`](./lib/core/constants/app_constants.dart) e preencha:
  ```dart
  static const String defaultSupabaseUrl = 'https://SEU_PROJETO.supabase.co';
  static const String defaultSupabaseAnonKey = 'SUA_CHAVE_PUBLICA_ANON';
  ```
  *(Esses valores são obtidos no Supabase em **Project Settings** > **API**)*.
* **Opção B (Pela Interface do App):** Ao abrir o app pela primeira vez sem configurar o código, uma tela moderna de boas-vindas solicitará a URL e a Anon Key.

---

## 📱 Executando em Desenvolvimento
```bash
# Baixar dependências
flutter pub get

# Executar no emulador/dispositivo Android ou no Windows
flutter run
```

---

## 📦 Como Exportar os Arquivos (.apk e .exe)

### 🤖 1. Gerando o APK para Android (.apk)
Para gerar o arquivo de instalação instalável em qualquer smartphone ou tablet Android:

```bash
flutter build apk --release
```
* O arquivo final será gerado em:
  `build/app/outputs/flutter-apk/app-release.apk`
* Para gerar APKs separados por arquitetura (gerando arquivos menores e mais rápidos):
  ```bash
  flutter build apk --split-per-abi
  ```

> **Dica:** Se o `flutter doctor` indicar licenças pendentes do Android SDK na sua máquina, rode uma única vez:
> `flutter doctor --android-licenses` e pressione `y` para aceitá-las.

---

### 💻 2. Gerando o Executável para Windows (.exe)
Para compilar a aplicação nativa para computadores com Windows 10/11:

1. Certifique-se de ter o pacote **"Desenvolvimento para desktop com C++"** instalado através do [Visual Studio Community](https://visualstudio.microsoft.com/vs/community/) (gratuito).
2. Execute o comando:
```bash
flutter build windows --release
```
* O executável e todas as DLLs necessárias serão gerados na pasta:
  `build/windows/x64/runner/Release/`
* O arquivo principal será:
  `build/windows/x64/runner/Release/luxpryme_stock.exe`

Para distribuir para outros computadores, basta compactar (ZIP) o conteúdo da pasta `Release` ou criar um instalador com ferramentas como Inno Setup.

---

## 🛡️ Regras de Negócio e Integridade
* **Proteção contra Estoque Negativo:** O app valida tanto na interface do usuário (desabilitando botões e conferindo inputs) quanto no próprio banco de dados PostgreSQL com a constraint `CHECK (quantity >= 0)`.
* **Sincronização Instantânea:** Quando um operador adiciona ou retira itens no chão de fábrica pelo Android, o estoque na tela do computador do gestor no Windows é atualizado no mesmo segundo via WebSockets.

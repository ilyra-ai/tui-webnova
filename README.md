# 🌌 WebNova Template Reutilizável

> **Um template TUI Web gráfico, premium, responsivo e em pt-BR para transformar scripts, automações e ferramentas locais em um painel bonito, claro e executável no navegador.** 🚀✨

![Status](https://img.shields.io/badge/status-template%20funcional-73f59f?style=for-the-badge)
![Idioma](https://img.shields.io/badge/idioma-pt--BR-78f7d0?style=for-the-badge)
![Stack](https://img.shields.io/badge/stack-Bash%20%2B%20Python%20%2B%20HTML%20%2B%20CSS%20%2B%20JS-8da2ff?style=for-the-badge)
![Fonte](https://img.shields.io/badge/fonte-Imprima-ffd166?style=for-the-badge)

---

## 📌 O que é o WebNova Template?

O **WebNova Template Reutilizável** é um ponto de partida completo para criar **TUIs Web locais** com aparência de dashboard moderno, mas sem depender de frameworks pesados, build, Node, Docker ou banco de dados.

Ele foi criado para quando você tem um script, instalador, auditoria, automação, pipeline, rotina DevOps, ferramenta de manutenção ou produto interno e quer entregar isso em um painel bonito, acessível e organizado.

Em vez de pedir para o usuário digitar números em um terminal cru, o WebNova oferece:

- 🧭 **Sidebar com ações reais**
- 🧱 **Cards premium clicáveis**
- 📊 **Gráfico Canvas nativo**
- 📋 **Tabela de histórico da sessão**
- 🖥️ **Console em tempo real com Server-Sent Events**
- 🌗 **Tema claro/escuro**
- 📱 **Layout responsivo**
- 🔎 **Busca rápida de ações**
- 📄 **Relatório temporário sob demanda**
- 🧩 **Pasta para extensões reais do projeto**

---

## ✨ Por que ele é tendência em 2026?

Interfaces de 2026 valorizam **clareza visual, baixo ruído, dashboards modulares, bento grids, glassmorphism controlado, acessibilidade, dark mode e microinterações úteis**. O WebNova aplica esses conceitos sem transformar o projeto em uma floresta de dependências.

O template segue uma direção visual moderna:

- 🌌 **Dark-first com tema claro opcional**
- 🧊 **Glassmorphism refinado**
- 🧱 **Bento-like cards**
- 🧠 **Hierarquia visual forte**
- 🔎 **Busca imediata**
- 📊 **Dados reais do ambiente**
- 🧘 **Interface limpa, sem excesso de estímulos**
- 📱 **Mobile-first/responsivo**
- 🎛️ **Cockpit operacional para scripts reais**

---

## 🧬 Arquitetura

```text
webnova-template.sh
│
├── Bash launcher
│   ├── valida Python
│   ├── define nome, versão, host e porta
│   └── inicia servidor local
│
├── Python embutido
│   ├── HTTP server local em 127.0.0.1
│   ├── token de sessão
│   ├── catálogo único de ações
│   ├── endpoints JSON
│   ├── streaming SSE do console
│   └── relatório temporário sob demanda
│
└── HTML/CSS/JS embutido
    ├── fonte Imprima
    ├── sidebar
    ├── cards
    ├── tabela
    ├── gráfico Canvas
    ├── console real
    ├── modal
    ├── toast
    ├── tema claro/escuro
    └── responsividade
```

---

## 🧰 Requisitos

Você precisa apenas de:

| Requisito | Uso |
|---|---|
| 🐚 `bash` | iniciar o template |
| 🐍 `python3` | rodar o servidor local |
| 🌐 navegador | abrir o painel WebNova |

Não precisa de:

- ❌ Node.js
- ❌ npm
- ❌ Docker
- ❌ banco de dados
- ❌ build frontend
- ❌ framework pesado

---

## 🚀 Como usar do zero, passo a passo para leigos

### 1. Baixe ou copie o arquivo

Coloque o arquivo no seu projeto com este nome:

```bash
webnova-template.sh
```

Exemplo:

```text
meu-projeto/
├── webnova-template.sh
├── README.md
└── src/
```

---

### 2. Dê permissão de execução

No terminal, entre na pasta do projeto:

```bash
cd meu-projeto
```

Depois rode:

```bash
chmod +x webnova-template.sh
```

---

### 3. Rode o teste interno

Antes de abrir o painel, valide o template:

```bash
./webnova-template.sh --self-test
```

Resultado esperado:

```text
SELF-TEST OK. Catalogo possui 14 acoes reais. Template WebNova funcional.
```

---

### 4. Abra o painel WebNova

Execute:

```bash
./webnova-template.sh
```

Ele vai mostrar uma URL local parecida com:

```text
http://127.0.0.1:8808/?token=...
```

Copie essa URL e cole no navegador.

---

### 5. Use os cards ou a sidebar

Dentro do painel:

- 🛰️ clique em **Status do ambiente**
- 🩺 rode **Health check completo**
- 🗂️ veja o **Mapa do projeto**
- 🌿 confira o **Status Git**
- 💾 visualize **Disco e armazenamento**
- 📄 gere um **Relatório temporário** somente quando quiser

Tudo aparece no **Console real** no lado direito.

---

## 🧩 Como usar em qualquer projeto

### Opção A — usar como painel de diagnóstico

Coloque o arquivo na raiz do projeto e rode:

```bash
./webnova-template.sh
```

Ele já mostra informações reais do ambiente e do projeto.

---

### Opção B — personalizar nome e versão sem editar o arquivo

Você pode trocar o nome visível do app usando variáveis:

```bash
WEBNOVA_APP_NOME="Meu Projeto Premium" WEBNOVA_APP_VERSAO="2.0.0" ./webnova-template.sh
```

---

### Opção C — escolher porta

```bash
WEBNOVA_PORT=8899 ./webnova-template.sh
```

---

### Opção D — não abrir navegador automaticamente

```bash
./webnova-template.sh --no-browser
```

---

### Opção E — executar uma ação pelo terminal

```bash
./webnova-template.sh --run-action status
```

---

## ⚙️ Catálogo de ações reais

| Ícone | Ação | Grupo | O que faz |
|---|---|---|---|
| 🛰️ | `status` | Diagnóstico | Mostra sistema, Python, disco, diretório e uptime |
| 🩺 | `health_check` | Diagnóstico | Valida ferramentas básicas disponíveis |
| 🗂️ | `list_project` | Projeto | Lista arquivos e diretórios do projeto atual |
| 🌿 | `git_status` | Projeto | Mostra status Git e últimos commits |
| 💾 | `disk_report` | Sistema | Exibe uso de disco e diretório atual |
| 🧠 | `memory_report` | Sistema | Exibe memória, carga e processos |
| 🌐 | `network_check` | Rede | Mostra rota, DNS e teste de conectividade |
| 📊 | `process_top` | Sistema | Lista processos principais |
| 🔐 | `env_report` | Ambiente | Mostra variáveis técnicas não sensíveis |
| 🐍 | `python_report` | Runtime | Valida Python, pip, venv e módulos padrão |
| 🟩 | `node_report` | Runtime | Valida Node/npm/pnpm/yarn/bun quando existirem |
| 🐳 | `docker_report` | Containers | Valida Docker e Docker Compose quando existirem |
| 🧩 | `custom_actions` | Extensão | Descobre scripts executáveis em `webnova-actions.d` |
| 📄 | `export_report` | Relatório | Gera relatório Markdown temporário sob demanda |

---

## 🧩 Como adicionar ações do seu projeto

Crie uma pasta chamada:

```bash
mkdir -p webnova-actions.d
```

Coloque scripts executáveis dentro dela:

```bash
cat > webnova-actions.d/minha-rotina.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
echo "Minha rotina real começou"
date
echo "Diretório atual: $(pwd)"
echo "Minha rotina real terminou"
SH

chmod +x webnova-actions.d/minha-rotina.sh
```

Depois, no painel, rode:

```text
🧩 Ações personalizadas
```

O WebNova vai descobrir os scripts reais existentes. A execução automática desses scripts pode ser adicionada ao seu fluxo quando você decidir quais rotinas do projeto devem virar botões oficiais.

---

## 🎨 Componentes visuais incluídos

- 🌌 Hero premium
- 🧭 Sidebar categorizada
- 🔎 Campo de busca
- 🧱 Cards responsivos
- 📊 Gráfico Canvas
- 📋 Tabela de histórico
- 🖥️ Console real
- 🪟 Modal explicativo
- 🍞 Toasts de feedback
- 🌗 Tema claro/escuro
- 🧩 Badges de risco
- 📱 Layout mobile-first
- ⌨️ Atalho `Ctrl + K` para busca
- 🧹 Limpeza do console
- 👁️ Ocultar/mostrar console

---

## 🖋️ Fonte padrão: Imprima

O template usa a fonte **Imprima** como padrão no HTML:

```html
<style>
@import url('https://fonts.googleapis.com/css2?family=Imprima&display=swap');
</style>
```

Classe CSS:

```css
.imprima-regular {
  font-family: "Imprima", sans-serif;
  font-weight: 400;
  font-style: normal;
}
```

---

## 🔐 Segurança operacional

O WebNova foi desenhado para ser local e controlado:

- 🔒 servidor em `127.0.0.1`
- 🔑 token de sessão na URL
- 🧾 relatório criado apenas quando solicitado
- 🧠 histórico somente em memória
- 🧯 ações padrão de leitura/diagnóstico
- 🚫 sem banco de dados
- 🚫 sem upload remoto
- 🚫 sem serviço público externo

---

## 🛠️ Estrutura recomendada para usar no seu projeto

```text
meu-projeto/
├── webnova-template.sh
├── webnova-actions.d/
│   ├── build.sh
│   ├── test.sh
│   └── deploy-local.sh
├── README.md
├── src/
└── tests/
```

---

## ✅ Checklist antes de publicar

- [ ] Rode `./webnova-template.sh --self-test`
- [ ] Abra o painel no navegador
- [ ] Teste `status`
- [ ] Teste `health_check`
- [ ] Teste `list_project`
- [ ] Se usar Git, teste `git_status`
- [ ] Adicione suas ações reais em `webnova-actions.d`
- [ ] Atualize este README com o nome do seu projeto
- [ ] Documente quais ações alteram o sistema
- [ ] Teste em tela pequena/mobile

---

## 🧪 Validação técnica

Comandos úteis:

```bash
bash -n webnova-template.sh
./webnova-template.sh --self-test
./webnova-template.sh --list-actions-json
./webnova-template.sh --menu-preview
./webnova-template.sh --run-action status
```

---

## 🚑 Solução de problemas

### O painel não abriu sozinho

Copie a URL exibida no terminal e cole no navegador.

### A porta está ocupada

Defina outra porta:

```bash
WEBNOVA_PORT=8899 ./webnova-template.sh
```

### Python não foi encontrado

Instale Python 3:

```bash
sudo apt update
sudo apt install -y python3
```

### O navegador mostra token inválido

Use exatamente a URL impressa no terminal, incluindo `?token=...`.

### O console não atualiza

Recarregue a página e rode a ação novamente. O console usa Server-Sent Events, então extensões ou proxies locais podem interferir.

---

## 🗺️ Roadmap sugerido

- 🧩 Execução oficial de ações customizadas pelo painel
- 🔐 Perfis de permissão por ação
- 📦 Exportação ZIP de diagnóstico
- 🌍 Internacionalização pt-BR/en-US
- 🧪 Testes automatizados com GitHub Actions
- 📊 Mais tipos de gráficos Canvas
- 📁 Navegador de arquivos interno somente leitura
- 🎨 Editor visual de tema
- 🧭 Command palette avançado
- 🧠 Assistente local de diagnóstico

---

## 📚 Referências úteis

- GitHub README: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes
- Server-Sent Events: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events
- EventSource: https://developer.mozilla.org/en-US/docs/Web/API/EventSource
- Canvas API: https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
- Google Fonts Imprima: https://fonts.google.com/specimen/Imprima

---

## ❤️ Filosofia do template

O WebNova não tenta ser um framework gigante. Ele é uma ponte elegante entre **scripts reais** e **experiência visual moderna**.

Ele existe para transformar terminal em cockpit, sem perder controle, clareza e simplicidade.

**Qualidade antes de pressa. Interface bonita, comando real, saída visível.** 🌌🚀

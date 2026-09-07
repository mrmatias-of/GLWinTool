# GL WinTool

<p align="center">
  <img src="assets/readme/glab-logo.png" alt="Logo G-LAB Cursos" width="760">
</p>

<p align="center">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0EA5E9?style=for-the-badge&logo=windows&logoColor=white">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1+-2563EB?style=for-the-badge&logo=powershell&logoColor=white">
  <img alt="WinGet" src="https://img.shields.io/badge/WinGet-integrado-16A34A?style=for-the-badge">
  <img alt="Idioma" src="https://img.shields.io/badge/interface-pt--BR-7C3AED?style=for-the-badge">
</p>

<p align="center">
  <strong>Central grafica para preparar, ajustar e manter ambientes Windows com rapidez, padrao e seguranca operacional.</strong>
</p>

<p align="center">
  Versao atual: <code>0.4.7</code>
</p>

<p align="center">
  <a href="#inicio-rapido">Inicio rapido</a> •
  <a href="#modulos">Modulos</a> •
  <a href="#seguranca-operacional">Seguranca</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="docs/ROADMAP.md">Plano completo</a>
</p>

---

## Visao geral

O **GL WinTool** e uma ferramenta Windows criada para acelerar rotinas de bancada, pos-formatacao, manutencao e padronizacao de maquinas.

O projeto reune instalacao de aplicativos, ajustes do Windows, remocao controlada de AppX, reparos, DNS, Windows Update e rotinas preventivas em uma interface unica, leve e em portugues.

![Banner do GL WinTool](assets/readme/hero.svg)

## Inicio rapido

O GL WinTool tem dois modos oficiais de uso:

- **Comando web**: ideal para suporte rapido, laboratorio e maquinas novas.
- **Executavel portatil**: ideal para pendrive, pasta tecnica ou distribuicao direta.

Execute no **Windows PowerShell**:

```powershell
irm https://www.glabcursos.com.br/win | iex
```

Fonte direta pelo GitHub:

```powershell
irm https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/web-bootstrap-template.ps1 | iex
```

Autoteste seguro para desenvolvimento:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -SelfTest
```

Gerar executavel local:

```powershell
Install-Module ps2exe -Scope CurrentUser
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
.\dist\GL-WinTool.exe -SelfTest
```

O executavel oficial pode ser distribuido sozinho. Ao iniciar em uma pasta nova, ele baixa automaticamente os arquivos necessarios (`assets`, `config`, `VERSION` e `update.json`) para a mesma pasta onde o `GL-WinTool.exe` esta.

## Preview

![Preview da interface](assets/readme/app-preview.svg)

## Destaques

| Area | Recursos |
| --- | --- |
| Aplicativos | Catalogo com 232 apps, busca, categorias, presets, icones e selecao persistente |
| Atualizacoes | Verificacao de updates, atualizacao dos selecionados, atualizacao geral e reparo de fontes |
| Ajustes Windows | Presets Minimo/Padrao/Avancado, checkboxes seletivos, verificacao, aplicacao, desfazer e backups |
| AppX | Remocao e reinstalacao controlada de apps provisionados, categorias, busca, preview, bloqueios e inventario antes da acao |
| Manutencao | DISM, SFC, reparo de rede, horario/NTP, limpeza de temporarios, relatorio de saude e ponto de restauracao |
| Operacao | Log integrado, progresso visual, confirmacoes e backups preventivos |

## Modulos

### Instalar

Catalogo de aplicativos organizado por categoria, com busca por nome, id, descricao e tags. A instalacao, atualizacao e remocao usam o instalador padrao do Windows, com suporte a pacotes WinGet e Microsoft Store.

### Ajustes

Ajustes do Windows em formato seletivo, inspirados no fluxo do WinUtil. A aba inclui presets **Minimo**, **Padrao** e **Avancado**, verificacao de estado, aplicacao e reversao dos ajustes compativeis. Acoes sensiveis ficam em fluxos dedicados, com confirmacao e backup quando aplicavel.

### Configurar

Area de manutencao rapida para tarefas como ponto de restauracao, limpeza de temporarios, relatorio de saude salvo em arquivo, reparo do Windows, reparo de rede, horario/NTP, reinicio do Explorer, modos de Windows Update e reparo dedicado de componentes de atualizacao.

No topo da aba existem fluxos por problema real:

- **Meu PC esta lento**: manutencao segura, limpeza de temporarios e reinicio do Explorer.
- **Apps nao instalam**: reparo das fontes do instalador e verificacao de atualizacoes.
- **Internet com problema**: limpeza de DNS, renovacao de IP e reset basico de rede.
- **Windows Update travou**: backup, reconstrucao de caches e reinicio dos servicos de atualizacao.

Tambem oferece atalhos para abrir backups, a pasta local do assistente e configuracoes oficiais do Windows.

### Atualizar

Painel para verificar atualizacoes disponiveis, atualizar aplicativos selecionados, atualizar todos os aplicativos detectados e reparar as fontes usadas pelo instalador.

### AppX

Remocao e reinstalacao controlada de aplicativos provisionados do Windows, com categorias, busca, selecao de itens seguros, confirmacao e inventario antes da remocao.

### Win11

Base inicial para rotinas de preparacao do Windows 11, com atalhos para download oficial, gerenciamento de disco, pasta Downloads e geracao inicial de `AutoUnattend.xml` em pt-BR. A criacao de pendrive e alteracoes destrutivas de disco continuam bloqueadas ate existir um fluxo proprio de selecao e confirmacao.

## Seguranca operacional

![Fluxo seguro de operacao](assets/readme/safety-flow.svg)

O GL WinTool foi desenhado para evitar alteracoes sensiveis sem contexto. Procedimentos de maior impacto passam por confirmacao, log e backups locais quando aplicavel.

Medidas implementadas:

- confirmacao antes de acoes destrutivas;
- backup antes de ajustes de registro;
- backup da configuracao DNS antes de alteracoes;
- exportacao de politicas locais antes de mudar ou reparar Windows Update;
- renomeio recuperavel dos caches do Windows Update em vez de exclusao direta;
- inventario AppX antes da remocao;
- tentativa de ponto de restauracao em ajustes e AppX quando executado como administrador;
- relatorio de saude salvo em pasta de backup;
- bloqueio contra acoes simultaneas;
- barra de progresso durante operacoes;
- log visivel na interface.

Os backups sao gravados em `backups/` dentro da copia local em execucao.

## Execucao local

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-GL-WinTool.ps1
```

Execucao direta:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1
```

Validacao sem abrir a interface:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

## Estrutura

```text
.
├── WinTool.ps1
├── Start-GL-WinTool.ps1
├── bootstrap.ps1
├── web-bootstrap-template.ps1
├── config
│   ├── apps.json
│   ├── appx.json
│   ├── presets.json
│   └── tweaks.json
├── assets
│   ├── icons
│   └── readme
├── docs
├── functions
├── pester
├── scripts
├── src
└── xaml
```

## Catalogos

| Arquivo | Finalidade |
| --- | --- |
| `config/apps.json` | Aplicativos disponiveis para instalacao, atualizacao e remocao |
| `config/presets.json` | Conjuntos prontos de aplicativos para cenarios comuns |
| `config/tweaks.json` | Ajustes do Windows, comandos controlados e itens planejados |
| `config/appx.json` | Aplicativos AppX provisionados/removiveis |

## Icones

Os icones dos aplicativos sao armazenados localmente em `assets/icons`.

Para regenerar os assets:

```powershell
powershell -ExecutionPolicy Bypass -File .\src\New-IconAssets.ps1
```

## Roadmap

O plano detalhado de evolucao esta em [`docs/ROADMAP.md`](docs/ROADMAP.md).
O relatorio de testes seguros esta em [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md).
O processo de lancamento oficial esta em [`docs/RELEASE.md`](docs/RELEASE.md).

| Fase | Objetivo | Status |
| --- | --- | --- |
| Base confiavel | Instalacao, remocao, atualizacao, validacao e compatibilidade PowerShell 5.1 | Em andamento avancado |
| Ajustes Windows | Mais ajustes seguros, deteccao de estado refinada e reversoes adicionais | Em andamento |
| AppX | Preview de remocao, restauracao quando possivel e categorias refinadas | Em andamento |
| Reparos | Windows Update, rede, horario/NTP, imagem do Windows e relatorio de saude | Em andamento avancado |
| Experiencia | Fluxos por problema real, textos mais claros e menos dependencia do menu lateral | Em andamento avancado |
| Windows 11 Creator | Download oficial, preparacao inicial, AutoUnattend, USB, drivers e ajustes offline | Iniciado avancado |
| Arquitetura | Modularizacao, XAML separado, testes Pester e pipeline de release | Planejado |

## Desenvolvimento

### Evolucao para aplicativo nativo

A versao atual usa uma base PowerShell/WPF empacotada como executavel para acelerar desenvolvimento e validacao em maquinas reais. O plano oficial e migrar gradualmente para um aplicativo nativo Windows, preservando os catalogos e fluxos ja validados:

1. separar regras, catalogos e rotinas em modulos independentes;
2. manter compatibilidade com o comando web e com o `GL-WinTool.exe`;
3. criar instalador oficial com atalhos, icone, pasta propria e atualizador;
4. migrar a interface para uma base nativa Windows;
5. manter releases versionadas no GitHub.

Antes de publicar alteracoes:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

Fluxo de publicacao:

```powershell
git add .
git commit -m "Descreva a mudanca"
git push
```

## Uso responsavel

O GL WinTool executa rotinas administrativas capazes de alterar configuracoes do Windows. Para ambientes profissionais, recomenda-se validar presets e ajustes em laboratorio antes da distribuicao em larga escala.









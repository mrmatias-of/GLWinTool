# GL WinTool

<p align="center">
  <img src="assets/readme/glab-logo.png" alt="Logo G-LAB Cursos" width="760">
</p>

<p align="center">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0EA5E9?style=for-the-badge&logo=windows&logoColor=white">
  <img alt="Windows App" src="https://img.shields.io/badge/App-Windows-2563EB?style=for-the-badge&logo=windows&logoColor=white">
  <img alt="WinGet" src="https://img.shields.io/badge/WinGet-integrado-16A34A?style=for-the-badge">
  <img alt="Idioma" src="https://img.shields.io/badge/interface-pt--BR-7C3AED?style=for-the-badge">
</p>

<p align="center">
  <strong>Central gráfica para preparar, ajustar e manter ambientes Windows com rapidez, padrão e segurança operacional.</strong>
</p>

<p align="center">
  Versao atual: <code>0.5.21</code>
</p>

<p align="center">
  <a href="#inicio-rapido">Inicio rapido</a> -
  <a href="#modulos">Modulos</a> -
  <a href="#seguranca-operacional">Seguranca</a> -
  <a href="#uso-responsavel">Uso responsavel</a>
</p>

---

## Visão geral

O **GL WinTool** é uma ferramenta Windows criada para acelerar rotinas de bancada, pós-formatação, manutenção e padronização de máquinas.

Ele reúne instalação de aplicativos, ajustes do Windows, remoção controlada de AppX, reparos, DNS, Windows Update e rotinas preventivas em uma interface única, leve e em português.

![Banner do GL WinTool](assets/readme/gl-win-tool-banner.png)

## Início rápido

O GL WinTool tem dois modos oficiais de uso:

- **Comando web**: ideal para suporte rápido, laboratório e máquinas novas.
- **Executável portátil**: ideal para pendrive, pasta técnica ou distribuição direta.

Execute no **Windows PowerShell**:

```powershell
irm https://www.glabcursos.com.br/win | iex
```

O executável oficial pode ser distribuído sozinho. Na versão nativa, o GL WinTool abre como aplicativo Windows, sem console PowerShell.

As atualizações sempre levam direto para a versão mais recente disponível. Se alguém estiver em uma versão antiga, o app não passa por atualizações intermediárias.

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

## Módulos

### Instalar

Catálogo de aplicativos organizado por categoria, com busca por nome, descrição e finalidade. A instalação, atualização e remoção usam o instalador padrão do Windows, com suporte a pacotes WinGet e Microsoft Store.

### Ajustes

Ajustes do Windows em formato seletivo, inspirados no fluxo do WinUtil. A aba inclui perfis **Mínimo**, **Padrão** e **Avançado**, verificação de estado, aplicação e reversão dos ajustes compatíveis. Ações sensíveis ficam em fluxos dedicados, com confirmação e backup quando aplicável.

### Configurar

Área de manutenção rápida para tarefas como ponto de restauração, limpeza de temporários, relatório de saúde, reparo do Windows, reparo de rede, horário/NTP, reinício do Explorer, modos de Windows Update e reparo dedicado de componentes de atualização.

No topo da aba existem fluxos por problema real:

- **Meu PC está lento**: manutenção segura, limpeza de temporários e reinício do Explorer.
- **Apps não instalam**: reparo das fontes do instalador e verificação de atualizações.
- **Internet com problema**: limpeza de DNS, renovacao de IP e reset basico de rede.
- **Windows Update travou**: backup, reconstrucao de caches e reinicio dos servicos de atualizacao.

Também oferece atalhos para backups, pasta local do assistente e configurações oficiais do Windows.

### Atualizar

Painel para verificar atualizações disponíveis, atualizar aplicativos selecionados, atualizar todos os aplicativos detectados e reparar as fontes usadas pelo instalador.

### AppX

Remoção e reinstalação controlada de aplicativos provisionados do Windows, com categorias, busca, seleção de itens seguros, confirmação e inventário antes da remoção.

### Win11

Base inicial para rotinas de preparação do Windows 11, com atalhos para download oficial, gerenciamento de disco, pasta Downloads e geração inicial de `AutoUnattend.xml` em pt-BR. A criação de pendrive e alterações destrutivas de disco continuam bloqueadas até existir um fluxo próprio de seleção e confirmação.

## Segurança operacional

![Fluxo seguro de operacao](assets/readme/safety-flow.svg)

O GL WinTool foi desenhado para evitar alterações sensíveis sem contexto. Procedimentos de maior impacto passam por confirmação, log e backups locais quando aplicável.

Medidas implementadas:

- confirmação antes de ações destrutivas;
- backup antes de ajustes de registro;
- backup da configuração DNS antes de alterações;
- exportação de políticas locais antes de mudar ou reparar Windows Update;
- renomeio recuperável dos caches do Windows Update em vez de exclusão direta;
- inventário AppX antes da remoção;
- tentativa de ponto de restauração em ajustes e AppX quando executado como administrador;
- relatório de saúde salvo em pasta de backup;
- bloqueio contra ações simultâneas;
- barra de progresso durante operações;
- log visível na interface.

Os backups sao gravados em `backups/` dentro da copia local em execucao.

## Uso responsável

O GL WinTool executa rotinas administrativas capazes de alterar configurações do Windows. Para ambientes profissionais, recomenda-se validar perfis e ajustes em laboratório antes da distribuição em larga escala.



















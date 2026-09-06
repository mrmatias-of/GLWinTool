# Assistente G-LAB

![Banner do Assistente G-LAB](assets/readme/hero.svg)

<p align="center">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1+-2563EB?style=for-the-badge&logo=powershell&logoColor=white">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0EA5E9?style=for-the-badge&logo=windows&logoColor=white">
  <img alt="WinGet" src="https://img.shields.io/badge/WinGet-ready-16A34A?style=for-the-badge">
  <img alt="Idioma" src="https://img.shields.io/badge/pt--BR-interface-7C3AED?style=for-the-badge">
</p>

O **Assistente G-LAB** e uma central Windows em PowerShell/WPF para preparar, instalar, ajustar e manter computadores com mais agilidade e seguranca operacional.

Ele foi inspirado no conceito do Chris Titus Tech WinUtil, mas segue uma identidade propria para o ecossistema G-LAB: interface em pt-BR, curadoria local, backups preventivos e um fluxo pensado para uso tecnico em bancada, laboratorio e suporte.

## Comece em um comando

Abra o **Windows PowerShell como administrador** e execute:

```powershell
irm https://www.glabcursos.com.br/win | iex
```

Alternativa direta pelo GitHub:

```powershell
irm https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/web-bootstrap-template.ps1 | iex
```

O comando deve ser executado no Windows PowerShell.

## Preview

![Preview da interface](assets/readme/app-preview.svg)

## O que ele faz hoje

- Instala, atualiza e remove aplicativos pelo instalador padrao do Windows.
- Catalogo com **232 aplicativos** organizados por categorias.
- Suporte a pacotes do WinGet e Microsoft Store.
- Busca por nome, categoria, id, descricao e tags.
- Selecao persistente entre categorias.
- Presets de instalacao para preparar maquinas rapidamente.
- Icones locais por aplicativo.
- Aba **Ajustes** com opcoes selecionaveis por checkbox.
- Ajustes seguros por registro e comandos controlados.
- Aba **Atualizar** com verificacao, update dos selecionados, update geral e reparo de fontes.
- Aba **AppX** para remover apps provisionados do Windows com confirmacao.
- Seletor DNS: padrao do provedor, Cloudflare, Google, Quad9 e AdGuard.
- Modos de Windows Update: padrao, avisar e desativar.
- Reparo do Windows com DISM e SFC.
- Limpeza de arquivos temporarios.
- Criacao de ponto de restauracao.
- Log integrado na interface.

## Seguranca antes da acao

![Fluxo seguro de operacao](assets/readme/safety-flow.svg)

O Assistente G-LAB evita executar alteracoes sensiveis no escuro. Antes de procedimentos de maior impacto, ele cria uma trilha de recuperacao quando possivel.

Medidas ja implementadas:

- confirmacao antes de acoes destrutivas;
- backup antes de ajustes de registro;
- backup da configuracao DNS antes de alterar;
- exportacao da politica local de Windows Update antes de mudar o modo;
- inventario AppX antes da remocao;
- tentativa de ponto de restauracao em ajustes e AppX quando executado como administrador;
- bloqueio contra duas acoes simultaneas;
- barra de progresso durante operacoes;
- log visivel para auditoria.

Os backups ficam na pasta `backups` dentro da copia local em execucao. Quando iniciado pelo comando remoto, a copia fica na pasta temporaria do Windows daquela execucao.

## Execucao local

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Assistente-GLAB.ps1
```

Ou diretamente:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1
```

Validar catalogos sem abrir a interface:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

## Estrutura do projeto

```text
.
├── WinTool.ps1
├── Start-Assistente-GLAB.ps1
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
│   └── ARCHITECTURE.md
├── functions
│   ├── private
│   └── public
├── pester
├── scripts
├── src
│   └── New-IconAssets.ps1
└── xaml
```

## Catalogos

### Aplicativos

Arquivo: `config/apps.json`

Campos principais:

- `name`: nome exibido.
- `id`: ID do pacote. Use `msstore:<id>` para Microsoft Store.
- `category`: categoria visivel na interface.
- `description`: descricao curta.
- `domain`: usado pelo gerador de icones.
- `tags`: termos de busca.

### Ajustes

Arquivo: `config/tweaks.json`

Tipos suportados:

- `registry`: cria ou altera uma chave de registro.
- `command`: executa um comando controlado.
- `planned`: aparece na interface, mas fica bloqueado.

Somente ajustes com `safe: true` podem ser selecionados e aplicados.

### AppX

Arquivo: `config/appx.json`

Contem aplicativos provisionados/removiveis do Windows. A remocao pede confirmacao, gera inventario antes de executar e ignora itens bloqueados.

## Gerar icones

```powershell
powershell -ExecutionPolicy Bypass -File .\src\New-IconAssets.ps1
```

## Plano de crescimento

### Fase 1 - Base confiavel

- Corrigir instalacao, remocao e atualizacao de apps.
- Garantir compatibilidade com Windows PowerShell 5.1.
- Validar catalogos antes de publicar.
- Manter UI em pt-BR.

Status: em andamento avancado.

### Fase 2 - Ajustes Windows

- Expandir ajustes seguros.
- Criar presets de ajustes: minimo, padrao e avancado.
- Detectar ajustes ja aplicados.
- Adicionar desfazer ajustes selecionados.
- Melhorar tela de preferencias.

Status: em andamento.

### Fase 3 - Apps e AppX

- Revisar catalogo de apps continuamente.
- Melhorar deteccao de apps instalados.
- Manter catalogo AppX externo em JSON.
- Adicionar preview antes de remover AppX.
- Criar restauracao/reinstalacao quando possivel.

Status: iniciado com catalogos importados.

### Fase 4 - Reparos e atualizacoes

- Reparar fontes do instalador padrao do Windows.
- Corrigir problemas do Windows Update.
- Corrigir rede.
- Corrigir horario/NTP.
- Gerar relatorio de saude do sistema.

Status: iniciado com verificacao de updates, reparo de fontes, backups preventivos e acoes de manutencao.

### Fase 5 - Windows 11 Creator

- Baixar ISO oficial.
- Criar pendrive bootavel.
- Gerar AutoUnattend.
- Injetar drivers.
- Aplicar ajustes offline.

Status: planejado.

### Fase 6 - Arquitetura

- Separar `WinTool.ps1` em modulos.
- Mover XAML para `xaml/inputXML.xaml`.
- Criar `Compile.ps1` completo.
- Adicionar testes Pester.
- Criar pipeline de release.

Status: planejado.

## Desenvolvimento

Antes de commitar:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

Publicacao:

```powershell
git add .
git commit -m "Descreva a mudanca"
git push
```

## Uso responsavel

O Assistente G-LAB executa rotinas administrativas capazes de alterar configuracoes do Windows. Para ambientes profissionais, recomenda-se validar presets e ajustes em laboratorio antes da distribuicao em larga escala.

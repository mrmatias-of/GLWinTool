# Assistente G-LAB

Central Windows em PowerShell/WPF para instalacao de apps, ajustes de sistema, manutencao, AppX, DNS, Windows Update e preparacao tecnica de maquinas.

Inspirado no conceito do Chris Titus Tech WinUtil, mas com identidade e curadoria propria para o ecossistema G-LAB.

## Comando rapido

```powershell
irm https://www.glabcursos.com.br/win | iex
```

Alternativa direta pelo GitHub:

```powershell
irm https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/web-bootstrap-template.ps1 | iex
```

## Recursos atuais

- Interface grafica WPF.
- Catalogo de apps em JSON com 232 entradas importadas da referencia WinUtil.
- Instalacao, atualizacao e desinstalacao via WinGet.
- Suporte a pacotes `winget` e `msstore`.
- Atualizacao automatica das fontes WinGet antes de instalar/remover.
- Confirmacao antes de acoes destrutivas.
- Busca por nome, categoria, id, descricao e tags.
- Selecao persistente entre categorias.
- Predefinicoes de apps.
- Marcacao automatica de apps instalados.
- Icones locais por aplicativo.
- Ajustes do Windows seletivos por checkbox.
- Ajustes seguros por registro e comandos controlados.
- Reinicio do Explorer apos ajustes visuais.
- Seletor DNS: provedor, Cloudflare, Google, Quad9 e AdGuard.
- Modos de Windows Update: padrao, avisar e desativar.
- Reparo do Windows com DISM e SFC.
- Limpeza de arquivos temporarios.
- Criacao de ponto de restauracao.
- Aba AppX com catalogo externo em JSON, remocoes seguras e itens sensiveis bloqueados.
- Aba Win11 com ponto inicial para Windows 11 Creator.
- Log integrado na interface.

## Execucao local

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-Assistente-GLAB.ps1
```

Ou diretamente:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1
```

Validar sem abrir a janela:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

## Estrutura

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
│   └── icons
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

### Apps

Arquivo: `config/apps.json`

Campos principais:

- `name`: nome exibido.
- `id`: ID do WinGet. Use `msstore:<id>` para Microsoft Store.
- `category`: categoria visivel na interface.
- `description`: descricao curta.
- `domain`: usado pelo gerador de icones.
- `tags`: termos de busca.

### Ajustes

Arquivo: `config/tweaks.json`

Tipos suportados:

- `registry`: cria/altera uma chave de registro.
- `command`: executa um comando controlado.
- `planned`: aparece na interface, mas fica bloqueado.

Somente ajustes com `safe: true` podem ser selecionados e aplicados.

### AppX

Arquivo: `config/appx.json`

Contem apps provisionados/removiveis inspirados na referencia WinUtil. A remocao pede confirmacao antes de executar.

## Seguranca operacional

Este projeto executa comandos administrativos no Windows. Use com criterio em maquinas de producao.

Medidas ja adotadas:

- acoes destrutivas pedem confirmacao;
- AppX sensiveis ficam bloqueados;
- ajustes planejados aparecem, mas nao executam;
- argumentos WinGet sao montados por funcao central;
- `ValidateOnly` valida catalogos e argumentos;
- logs ficam visiveis para auditoria.

Recomendado para ambientes profissionais:

- usar ponto de restauracao antes de alteracoes amplas;
- testar presets em VM antes de usar em bancada;
- publicar releases versionadas;
- assinar scripts;
- evitar apontar o bootstrap para branches instaveis.

## Plano de crescimento

### Fase 1 - Base confiavel

- Corrigir instalacao/remocao/atualizacao de apps.
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

Status: proxima prioridade.

### Fase 3 - Apps e AppX

- Expandir e revisar catalogo de apps.
- Melhorar deteccao de apps instalados.
- Manter catalogo AppX externo em JSON.
- Adicionar preview antes de remover AppX.
- Criar restauracao/reinstalacao quando possivel.

Status: iniciado com catalogos importados.

### Fase 4 - Reparos e atualizacoes

- Fix WinGet.
- Fix Windows Update.
- Fix rede.
- Fix horario/NTP.
- Relatorio de saude do sistema.

Status: iniciado.

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

## Gerar icones

```powershell
powershell -ExecutionPolicy Bypass -File .\src\New-IconAssets.ps1
```

## Desenvolvimento

Antes de commitar:

```powershell
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
```

Commit e publicacao:

```powershell
git add .
git commit -m "Descreva a mudanca"
git push
```

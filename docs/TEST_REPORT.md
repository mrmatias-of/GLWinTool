# Relatorio de testes seguros

Ultima revisao: 2026-09-06

## Comandos executados

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\WinTool.ps1 -ValidateOnly
powershell -NoProfile -ExecutionPolicy Bypass -File .\WinTool.ps1 -SelfTest
```

## Resultado

- Validacao geral: OK.
- Autoteste seguro: OK.
- Catalogo de apps: 232 de 232 em relacao a referencia WinUtil.
- Catalogo AppX: 33 de 33 em relacao a referencia WinUtil.
- Ajustes: 29 seguros implementados de 66 itens da referencia.

## Cobertura do autoteste

- Carregamento de JSON.
- IDs duplicados no catalogo.
- Argumentos de instalar, atualizar e desinstalar apps.
- Regra de desinstalacao sem `--accept-package-agreements`.
- Apps Microsoft Store com origem `msstore`.
- Presets Minimo, Padrao e Avancado da aba Ajustes.
- Selecao segura de AppX.
- Existencia dos botoes principais da interface.

## O que nao foi executado automaticamente

As acoes abaixo alteram o Windows e devem ser testadas manualmente em maquina de laboratorio ou snapshot:

- aplicar/desfazer ajustes de registro;
- remover AppX;
- instalar/desinstalar aplicativos reais;
- reparar rede;
- reparar Windows Update;
- executar DISM/SFC;
- limpar temporarios;
- reiniciar Explorer.

## Comparacao com a referencia

O comportamento principal ja segue o modelo da referencia: selecao por checkbox, presets, confirmacao, progresso, log e execucao por acoes. A diferenca proposital e que o GL WinTool mantem somente ajustes seguros ativos; itens sensiveis precisam de fluxo dedicado com backup, confirmacao e reversao clara.


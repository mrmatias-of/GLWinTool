# Plano de melhorias e implementacao

Este documento organiza a evolucao do GL WinTool em frentes praticas de produto, seguranca e manutencao.

## 1. Experiencia do usuario

- Colocar as acoes principais dentro da aba correspondente.
- Manter a lateral apenas para atalhos globais.
- Reduzir termos tecnicos na interface.
- Exibir mensagens claras antes, durante e depois das operacoes.
- Criar estados vazios para busca sem resultado.
- Destacar aba ativa e contagem de selecionados.
- Padronizar botoes, cards, cores e espacamentos.

## 2. Instalacao de aplicativos

- Manter catalogo de apps em JSON.
- Suportar WinGet e Microsoft Store.
- Selecionar apps instalados automaticamente.
- Verificar atualizacoes disponiveis.
- Atualizar selecionados ou todos.
- Tratar falhas por app sem interromper o lote inteiro.
- Melhorar logs com progresso por item.

## 3. Ajustes do Windows

- Presets Minimo, Padrao e Avancado.
- Verificar estado atual dos ajustes.
- Aplicar ajustes com backup previo.
- Desfazer ajustes reversiveis.
- Ampliar catalogo com ajustes seguros da referencia.
- Separar ajustes sensiveis em fluxo avancado com confirmacao dedicada.

## 4. AppX e bloatware

- Agrupar AppX por categoria.
- Permitir busca por nome, pacote e descricao.
- Marcar apenas itens seguros em lote.
- Exibir previa antes de remover.
- Salvar inventario antes de executar.
- Criar fluxo de restauracao quando houver pacote recuperavel. Status: iniciado via reinstalacao pelo instalador de apps.
- Manter itens criticos bloqueados.

## 5. Manutencao e reparos

- Fluxos por problema real no topo da aba Configurar. Status: implementado para PC lento, apps que nao instalam, internet com problema e Windows Update travado.
- Relatorio rapido de saude do sistema. Status: implementado com log e arquivo local em backup.
- Reparo de imagem Windows com DISM/SFC.
- Reparo basico de rede.
- Correcao de horario/NTP.
- Reparo de fontes do instalador.
- Reparo de Windows Update em fluxo dedicado. Status: implementado com backup, parada de servicos, renomeio recuperavel de caches e reinicio dos servicos.
- Limpeza de temporarios com log de itens ignorados.

## 6. Windows 11 Creator

- Abrir fontes oficiais de ISO. Status: implementado.
- Abrir Gerenciamento de Disco para conferencia manual. Status: implementado.
- Abrir pasta Downloads para localizar ISO/ferramentas. Status: implementado.
- Preparar fluxo de criacao de midia USB.
- Gerar AutoUnattend. Status: implementado modelo inicial pt-BR sem formatacao automatica.
- Injetar drivers em imagem offline.
- Aplicar ajustes offline.
- Adicionar validacoes antes de formatar pendrive.

## 7. Seguranca operacional

- Confirmar acoes destrutivas.
- Criar backups locais por sessao.
- Exportar chaves de registro antes de alterar.
- Salvar inventario AppX antes de remover.
- Tentar criar ponto de restauracao quando houver permissao.
- Bloquear acoes simultaneas.
- Evitar comandos destrutivos sem alvo validado.

## 8. Arquitetura

- Separar `WinTool.ps1` em modulos.
- Mover XAML para arquivo dedicado.
- Criar testes Pester.
- Criar pipeline de release.
- Versionar releases estaveis.
- Assinar scripts em etapa futura.

## Status atual

- Base de apps importada e funcional.
- Interface em evolucao.
- Backups preventivos implementados.
- AppX com fluxo controlado.
- Ajustes com presets e reversao parcial.
- Reparos basicos avancados iniciados.


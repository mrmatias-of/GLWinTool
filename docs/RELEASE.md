# Lancamento oficial

## Como publicar uma atualizacao

1. Atualize `VERSION`.
2. Atualize `update.json` com a mesma versao.
3. Gere o executavel:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
.\dist\GL-WinTool.exe -SelfTest
```

4. Compacte o conteudo da pasta `dist` em `GL-WinTool.zip`.
5. Crie uma release no GitHub com tag da versao, por exemplo `v0.4.0`.
6. Anexe o arquivo `GL-WinTool.zip` na release.
7. Suba o commit com `VERSION`, `update.json` e documentacao.

## Como o app checa atualizacoes

Existem dois modos oficiais de distribuicao:

- comando web via `irm https://www.glabcursos.com.br/win | iex`;
- executavel portatil `GL-WinTool.exe`.

Ao iniciar, o app mostra uma tela de busca de atualizacoes antes da janela principal. Se houver versao nova, o botao **Baixar atualizacao** fica obrigatorio e baixa o pacote oficial `GL-WinTool.zip` da release mais recente. Se nao houver atualizacao, o app informa rapidamente que esta atualizado e abre a janela principal automaticamente.

O `GL-WinTool.exe` tambem pode ser distribuido sozinho. Quando ele e executado em uma pasta sem `assets`, `config`, `VERSION` ou `update.json`, baixa automaticamente o pacote oficial da release mais recente e extrai esses arquivos na mesma pasta do executavel.

A aba **Atualizar** tambem permite checagem manual e consulta:

```text
https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/update.json
```

Ela compara a versao publicada com o arquivo local `VERSION`.
Quando houver atualizacao, o download direto usa:

```text
https://github.com/mrmatias-of/assistente-glab/releases/latest/download/GL-WinTool.zip
```

## Regra recomendada

- Builds de teste: use sufixo `-dev`.
- Builds oficiais: use tag sem `-dev`, por exemplo `0.4.0`.
- Nunca substitua release antiga: publique uma nova tag.


# Lancamento oficial

## Como publicar uma atualizacao

1. Atualize `VERSION`.
2. Atualize `update.json` com a mesma versao.
3. Gere o executavel:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
.\dist\Assistente-G-LAB.exe -SelfTest
```

4. Compacte a pasta `dist` em um `.zip`.
5. Crie uma release no GitHub com tag da versao, por exemplo `v0.4.0`.
6. Anexe o `.zip` da pasta `dist`.
7. Suba o commit com `VERSION`, `update.json` e documentacao.

## Como o app checa atualizacoes

A aba **Atualizar** consulta:

```text
https://raw.githubusercontent.com/mrmatias-of/assistente-glab/main/update.json
```

Ela compara a versao publicada com o arquivo local `VERSION`.

## Regra recomendada

- Builds de teste: use sufixo `-dev`.
- Builds oficiais: use tag sem `-dev`, por exemplo `0.4.0`.
- Nunca substitua release antiga: publique uma nova tag.

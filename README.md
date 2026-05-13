# SOFTSKILL

Repositório pessoal de skills, agentes e scripts para Claude Code.

## Estrutura

```
SOFTSKILL/
├── skills/        # Skills customizadas para Claude Code (.md)
├── agents/        # Configurações e prompts de agentes
├── scripts/       # Scripts utilitários (PowerShell, Bash, Python...)
└── README.md
```

## Como usar uma skill no Claude Code

1. Copie o arquivo `.md` da pasta `skills/` para `~/.claude/skills/`
2. Reinicie o Claude Code
3. Use `/nome-da-skill` no chat

## Como adicionar uma nova skill

Crie um arquivo `.md` em `skills/` com o frontmatter:

```markdown
---
name: nome-da-skill
description: O que essa skill faz
---

Instruções da skill aqui...
```

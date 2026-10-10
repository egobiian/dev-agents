# dev-agents

[English](README.md) · **Español**

Una colección de agentes y skills de IA para el desarrollo de software, organizada por stack, para copiar en tus propios proyectos como ficheros sueltos. Está en desarrollo: las secciones, los nombres y el contenido todavía pueden cambiar.

## Secciones

| Sección | Para |
| :- | :- |
| [core](core/README.md) | Cualquier proyecto: flujo de git y comprobaciones previas al commit |
| [astro](astro/README.md) | Proyectos con [Astro](https://astro.build) |
| [python](python/README.md) | Proyectos con Python |

Cada sección tiene una carpeta `agents/` con [subagentes de Claude Code](https://code.claude.com/docs/en/sub-agents) y una carpeta `skills/` con skills en el formato [Agent Skills](https://agentskills.io/specification). Su `README.md` lista lo que contiene.

## Descargar una sección con curl

Ejecútalo desde la raíz de tu proyecto. Copia los agentes y las skills de una sección dentro de `.claude/`:

```bash
mkdir -p .claude
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz -C .claude --strip-components=2 \
    dev-agents-main/core/agents dev-agents-main/core/skills
```

Sustituye `core` por la sección que quieras, y `.claude` por otro destino como `~/.claude` para tenerlos en todos tus proyectos. Los ficheros llegan como copias sueltas, sin vínculo con este repositorio. Vuelve a ejecutar el comando para actualizarlos.

## Añadir a la colección

Las convenciones para añadir agentes, skills y secciones están en [AGENTS.md](AGENTS.md).

## Licencia

[MIT](LICENSE)

# dev-agents

[English](README.md) · **Español**

Una colección de agentes y skills de IA para el desarrollo de software, organizada por stack, para copiar en tus propios proyectos como ficheros sueltos. Está en desarrollo: las secciones, los nombres y el contenido todavía pueden cambiar.

## Secciones

**Cualquier proyecto**

| Sección | Para |
| :- | :- |
| [core](core/README.md) | Flujo de git, comprobaciones previas al commit, y delegar en agentes gastando pocos tokens |

**Lenguajes y frameworks**

| Sección | Para |
| :- | :- |
| [astro](astro/README.md) | Proyectos con [Astro](https://astro.build) |
| [python](python/README.md) | Proyectos con Python |

**Videojuegos**

| Sección | Para |
| :- | :- |
| [godot](godot/README.md) | Videojuegos con [Godot](https://godotengine.org): jugabilidad, interfaz, shaders, la comprobación previa al commit y niveles de plataformas 2D |
| [pixel-art](pixel-art/README.md) | Pixel art: guía de estilo, paleta, dibujo, generación y comprobaciones |
| [audio](audio/README.md) | Sonido hecho con modelos generativos de audio: dirección sonora, generación, procesado y bucles |

Cada sección tiene una carpeta `agents/` con [subagentes de Claude Code](https://code.claude.com/docs/en/sub-agents) y una carpeta `skills/` con skills en el formato [Agent Skills](https://agentskills.io/specification). Su `README.md` lista lo que contiene, agrupado por el tipo de proyecto al que sirve.

## Descargar una sección con curl

Ejecútalo desde la raíz de tu proyecto. Copia los agentes y las skills de una sección dentro de `.claude/`:

```bash
mkdir -p .claude
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz -C .claude --strip-components=2 \
    dev-agents-main/core/agents dev-agents-main/core/skills
```

Sustituye `core` por la sección que quieras, o pon varios pares de rutas para descargar varias secciones a la vez. Sustituye `.claude` por otro destino como `~/.claude` para tenerlos en todos tus proyectos. Los ficheros llegan como copias sueltas, sin vínculo con este repositorio. Vuelve a ejecutar el comando para actualizarlos.

## Descargar los hooks de git con curl

Ejecútalo desde la raíz de tu repositorio. Copia los dos hooks de git que usa este repositorio dentro de `.githooks/` y le indica a git que los ejecute:

```bash
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz --strip-components=1 dev-agents-main/.githooks
git config core.hooksPath .githooks
```

`commit-msg` rechaza cualquier mensaje de commit que no sea una sola línea con la forma `<type>: <description>`, y `pre-push` rechaza los commits sin firma. Lo que espera cada uno está en [.githooks/README.md](.githooks/README.md), que se copia junto con ellos.

## Añadir a la colección

Las convenciones para añadir agentes, skills y secciones están en [AGENTS.md](AGENTS.md).

## Licencia

[MIT](LICENSE)

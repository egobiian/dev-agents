# Audio

Agents and skills for the sound of a game made with generative audio models: its sound direction, the generation of effects and music, and the processing that turns a chosen take into a file the game plays. Names in this section start with `audio-`.

Nothing here depends on a particular model or game engine. Where the models run, the command that generates a batch and the batch format are written once per machine in `audio/tool.local.md`, a file git ignores, from a template in `audio-run-batches`. The first time, the agent asks for them: it never installs a model or looks for one. Where an engine needs a step of its own, such as a loop point in Godot, the step is named as an example.

## Agents

| Agent | What it does |
| :- | :- |
| [audio-sound-designer](agents/audio-sound-designer.md) | Writes prompts and batches for sound effects and music, runs them gently on the machine, rules out failed takes by measuring them, lets the owner choose by ear, and finishes the chosen take at its fixed name |

The agent preloads the three skills through the `skills` field of its frontmatter, so copy the whole section rather than single files.

## Skills

| Skill | What it does |
| :- | :- |
| [audio-style-guide](skills/audio-style-guide/SKILL.md) | Writes the audio style guide: character, tracks with tempo, key and loop, effect rules, prompt patterns, processing, loudness table, generation limits and files, from a template |
| [audio-run-batches](skills/audio-run-batches/SKILL.md) | Sets up the local notes on where the models run, and runs generation batches one after another with rests, a wait while the machine is throttled, and a log |
| [audio-process-takes](skills/audio-process-takes/SKILL.md) | Measures takes to rule out failures and match levels, builds a page to listen to them side by side, trims effects, encodes tracks to OGG, and finds and cuts seamless loops |

## Installing the models locally

[local-models.md](skills/audio-run-batches/references/local-models.md) tells how the sound of a complete game was generated offline on a Mac with Apple Silicon: sound effects with [MOSS-SoundEffect v2.0](https://huggingface.co/OpenMOSS-Team/MOSS-SoundEffect-v2.0) and music with [ACE-Step 1.5](https://github.com/ACE-Step/ACE-Step-1.5), each in its own environment, with the versions it was verified with, the changes that make them run on the Mac's GPU, the settings that were measured to work, and how to connect them to the agent. It sits inside `audio-run-batches`, so it is installed with the skill.

## Requirements

The runner of `audio-run-batches` needs a POSIX shell; its throttling wait uses macOS's `pmset` and is skipped elsewhere. The scripts of `audio-process-takes` need Python 3.10 or later with `numpy` and `soundfile` 0.12 or later.

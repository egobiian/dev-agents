# Local models: one way to install them

How the sound effects and music of a game were generated on a Mac with Apple Silicon, offline, with two open-licensed models. It is one working setup, not the only one: any model that a command can run on a batch file fits the `audio-run-batches` runner.

| For | Model | License | Output |
| :- | :- | :- | :- |
| Sound effects | [MOSS-SoundEffect v2.0](https://huggingface.co/OpenMOSS-Team/MOSS-SoundEffect-v2.0) | Apache-2.0 | 48 kHz mono, up to 30 s |
| Music | [ACE-Step 1.5](https://github.com/ACE-Step/ACE-Step-1.5) | MIT | 48 kHz stereo, instrumental, 10 s to 10 min |

Both allow commercial use of what they generate, with no royalties.

## What you need

- A Mac with Apple Silicon. The models run on its GPU through PyTorch's MPS backend. A machine with 24 GB of memory runs either one.
- About 25 GB of free disk: some 2.5 GB of Python environments and some 20 GB of model weights.
- [uv](https://docs.astral.sh/uv/) (`brew install uv`) and git (`xcode-select --install`).
- No account and no token: the weights download anonymously, and after that everything runs offline.

## The layout

The two models need libraries that conflict with each other, so each one gets an **isolated environment of its own** and runs as a separate process. A small wrapper of your own, in its own environment with only `numpy` and `soundfile`, reads a batch file and runs them:

```text
<audio-tools>/
  engines/
    sfx/                  pyproject.toml, .venv and the effects worker script
    music/
      ACE-Step-1.5/       its own checkout, .venv and checkpoints/
      worker.py           the music worker script
  models/
    moss-soundeffect-v2.0/
  <wrapper>               reads a batch file and runs the workers
```

Each worker is a short Python script run with its model's own Python: it loads the model once, generates every take the batch asks for in order, with a rest between them, and writes each take as a WAV. Writing its results after every take means a crash or a Ctrl-C keeps what was already finished.

## Sound effects: MOSS-SoundEffect v2.0

**Environment.** A `pyproject.toml` of its own, for Python 3.12:

```toml
[project]
name = "sfx-engine"
version = "0.1.0"
requires-python = ">=3.12,<3.13"
dependencies = [
    "moss-soundeffect-v2 @ git+https://github.com/OpenMOSS/MOSS-TTS@934d6826b084c46a0d033402174d5f8ac4ed2519#subdirectory=moss_soundeffect_v2",
    "torch==2.9.0",
    "torchaudio==2.9.0",
    "huggingface_hub",
    "soundfile",
]

[tool.uv]
package = false
environments = ["sys_platform == 'darwin' and platform_machine == 'arm64'"]
```

Then `uv sync` in that folder. About 1 GB.

**Weights.** About 10 GB, with the environment's own Python and no token:

```python
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="OpenMOSS-Team/MOSS-SoundEffect-v2.0",
    revision="e35df4d82fbe87fcd5d14e5d100e349c0c3c076d",
    local_dir="models/moss-soundeffect-v2.0",
    token=False,
)
```

**Running it on MPS.** Upstream targets CUDA, and three things have to change:

- Set `TORCHDYNAMO_DISABLE=1`: upstream wraps the model in `torch.compile` with CUDA graphs.
- MPS has no `float64`. Upstream computes its sinusoidal timestep embedding, `sinusoidal_embedding_1d`, in `float64`: replace that function, in each of the modules that use it (`diffsynth.models.wan_video_dit`, `diffsynth.models.wan_audio_dit` and `diffsynth.pipelines.wan_audio` inside `moss_soundeffect_v2`), with one that does the same math on the CPU and moves the result back to the input's device and dtype. Do it after importing them and before building the pipeline.
- MPS has no `complex128`. After loading, cast the transformer's rotary buffers, `pipe.transformer.freqs_cis_0`, `_1` and `_2`, to `complex64` on the CPU and move them back to the pipeline's device.

With both patches, the output on MPS matches the CPU's.

**Calling it.** Load with `MossSoundEffectPipeline.from_pretrained(<model dir>, torch_dtype=torch.bfloat16, device="mps")`, then call the pipeline with the prompt, `seconds`, `num_inference_steps=25`, `cfg_scale=4.0`, `max_inference_seconds=30` and a `seed`. What was measured:

- The denoising canvas has to stay at **30 s**. Shorter canvases give noise or the wrong sound: `seconds` only crops the result.
- 25 steps sound the same as 50.
- About a minute per effect, whatever its length, plus 15 to 40 s to load the model once.
- The same seed and prompt give the same sound.
- The sound often starts after some silence: trim the start and the end afterwards. Ask for a little more length than the sound needs.
- Prompts work in plain English describing a real physical sound, as the `audio-sound-designer` agent writes them. The pipeline adds the duration to the prompt itself.

## Music: ACE-Step 1.5

**Code and environment.** Its own checkout, at a fixed commit, with its own lockfile:

```bash
git clone https://github.com/ACE-Step/ACE-Step-1.5.git engines/music/ACE-Step-1.5
git -C engines/music/ACE-Step-1.5 checkout --detach ca1e85fe9430179831e6bc6be790c332190a3866
cd engines/music/ACE-Step-1.5 && uv sync --locked --python 3.12
```

About 1.5 GB.

**Weights.** About 10 GB, into the checkout's `checkpoints/`, with the same `snapshot_download` call: `repo_id="ACE-Step/Ace-Step1.5"`, `revision="19671f406d603126926c1b7e2adc169acbcade22"`, `local_dir="engines/music/ACE-Step-1.5/checkpoints"`, `token=False`.

**Calling it.** Never through its launch scripts: they check for updates and start web servers. Use its Python API from the checkout's own Python, with the checkout on `sys.path`:

- the diffusion model: `AceStepHandler().initialize_service(project_root=<checkout>, config_path="acestep-v15-turbo", device="mps")`;
- the language model, through MLX: `LLMHandler().initialize(checkpoint_dir=<checkout>/checkpoints, lm_model_path="acestep-5Hz-lm-1.7B", backend="mlx", device="mps")`;
- each track: `generate_music(dit, lm, GenerationParams(caption=<prompt>, instrumental=True, duration=<seconds>, seed=<seed>, inference_steps=8, bpm=<bpm>, keyscale="<key>"), GenerationConfig(batch_size=1, use_random_seed=False, audio_format="wav"), save_dir=<folder>)`.

What was measured:

- About 65 s per 30 s of music, plus 30 to 50 s to load the models once.
- The tempo it plays is close to the one asked, not equal to it: measure it before cutting a loop, as `audio-process-takes` does.
- A track may end with a few seconds of silence.
- Write WAV and encode at the end: its OGG writer failed on long tracks.

## Offline, no telemetry

Every worker runs with:

```bash
HF_HUB_OFFLINE=1 HF_HUB_DISABLE_TELEMETRY=1 GRADIO_ANALYTICS_ENABLED=False TOKENIZERS_PARALLELISM=false
```

Downloads run with `HF_HUB_DISABLE_TELEMETRY=1` and without `HF_TOKEN` in the environment.

## What the wrapper adds

- One run per model for a whole batch, so each model loads once.
- A rest between takes, set in the batch file: generation heats the machine.
- Beside each take, a JSON sidecar with its prompt, seed, steps, length, model and revision, license, date and `"ai_generated": true`. The listening page of `audio-process-takes` reads its prompt and seed, and the record keeps what a store asks when it requires generated content to be declared.
- For effects: mono, silence trimmed at both ends, very short fades, peak normalised to -1 dBFS. For music: stereo kept, trailing silence trimmed, a 1 s fade-out.
- Numbered outputs that never overwrite an earlier take.

## Connect it to the agents

Write `audio/tool.local.md` in the game's repository from the template in [../assets/tool-local-template.md](../assets/tool-local-template.md): `TOOL_DIR` is the wrapper's folder, `GENERATE` the command that runs one batch file, `PYTHON` a Python with `numpy` and `soundfile`, and the batch format the wrapper reads. Git ignores the file: it names local paths.

## Licenses and use

- The models' licenses allow commercial use of their output.
- Audio made only by a model may not be protected by copyright in the United States or the European Union: you can use it, and so could someone who extracts it from the game.
- Some stores ask for generated content to be declared: the sidecars record it.
- Never ask a model to imitate an artist, a song or a game. Describe the instruments, the tempo, the rhythm and the mood.

## Removing it

The environments and the weights take about 25 GB. Deleting `models/`, the effects environment's `.venv` and the music checkout frees them; the same steps install them again.

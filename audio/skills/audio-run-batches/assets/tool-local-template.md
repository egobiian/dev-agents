# Local audio tool

Git ignores this file (`*.local.md`). It says where the audio models run on this machine. Nothing in it — the folder, the command, the tool's name — is ever written to a committed file.

TOOL_DIR=<the folder the generation command runs in>
GENERATE=<the command that generates one batch; the batch file's absolute path is appended to it>
PYTHON=<a Python with numpy and soundfile, for the processing scripts>
REST_BETWEEN_BATCHES=<seconds of rest between batches; 300 if left out>

## Models

- Effects: <model and version; the settings the command uses; about how long one effect takes>
- Music: <model and version; the settings the command uses; about how long one track takes, and any time to load the model>

## Batch file

<The format the command reads, with one example of an effect and one of a track: the name of each take, the prompt, the length asked, how many takes and their seeds, tempo and key for a track, the rest between sounds, and where the outputs go.>

- Outputs: <where each take is written, its format, and whether a JSON sidecar beside it holds its prompt, seed and length>.
- <What the tool already does on its own, such as trimming silence or normalising, and any format it writes badly>.
- <Anything else worth knowing: a log that arrives in blocks, files written only at the end of the batch>.

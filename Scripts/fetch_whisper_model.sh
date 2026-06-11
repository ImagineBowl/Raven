#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Raven/Resources/WhisperModels"

echo "Fetching openai_whisper-tiny into $DEST"

pip3 install -q huggingface_hub

export ROOT
python3 - <<'PY'
from huggingface_hub import snapshot_download
import os

root = os.environ["ROOT"]
dest = os.path.join(root, "Raven/Resources/WhisperModels")
os.makedirs(dest, exist_ok=True)

snapshot_download(
    repo_id="argmaxinc/whisperkit-coreml",
    allow_patterns=["openai_whisper-tiny/**"],
    local_dir=dest,
    local_dir_use_symlinks=False,
)

cache_dir = os.path.join(dest, ".cache")
if os.path.isdir(cache_dir):
    import shutil
    shutil.rmtree(cache_dir)

print(f"Whisper model ready at {dest}/openai_whisper-tiny")
PY

#!/usr/bin/env bash
set -Eeuo pipefail
export PIP_ROOT_USER_ACTION=ignore

log(){ printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
warn(){ printf '[%s] [WARN] %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }
trap 'code=$?; echo "[ERROR] exit $code at line $LINENO"; exit $code' ERR
sanitize(){ local s="${1:-}"; s="${s//\"/}"; echo -n "$s"; }

# --- WORKSPACE autodetect ---
if [ -z "${WORKSPACE:-}" ]; then
  if [ -d "/runpod-volume" ]; then
    WORKSPACE="/runpod-volume"
  else
    WORKSPACE="/workspace"
  fi
fi
log "WORKSPACE set to: ${WORKSPACE}"

# ComfyUIの場所を永続領域に設定
export COMFY_ROOT="${WORKSPACE}/ComfyUI"

# === ComfyUI 初回セットアップ ===
if [ ! -d "${COMFY_ROOT}" ]; then
  log "ComfyUI not found in workspace, cloning for the first time..."
  git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFY_ROOT}"
  log "ComfyUI cloned into ${COMFY_ROOT}"
fi

# 依存関係のインストール (torch等はDockerfileのバージョンを維持)
log "Installing/checking ComfyUI requirements..."
python3 -m pip install -r "${COMFY_ROOT}/requirements.txt" --upgrade --no-deps torch torchvision torchaudio

# === SageAttentionのインストール ===
log "Installing SageAttention..."
TORCH_CUDA_ARCH_LIST=8.9 python3 -m pip install git+https://github.com/thu-ml/SageAttention.git
log "SageAttention installed."

COMFY_PORT="${COMFY_PORT:-8188}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"

ALWAYS_DL="${ALWAYS_DL:-1}"
CLEAR_MODELS_BEFORE_DL="${CLEAR_MODELS_BEFORE_DL:-0}"
INSTALL_MANAGER="${INSTALL_MANAGER:-1}"
INSTALL_VHS="${INSTALL_VHS:-1}"
JUPYTER_TOKEN="$(sanitize "${JUPYTER_TOKEN:-}")"

# === FS layout (logs only) ===
mkdir -p "${WORKSPACE}/logs"

# === ComfyUI-Manager 自動導入 ===
if [ "${INSTALL_MANAGER}" = "1" ]; then
  MANAGER_DIR="${COMFY_ROOT}/custom_nodes/ComfyUI-Manager"
  if [ ! -d "${MANAGER_DIR}" ]; then
    log "Installing ComfyUI-Manager from GitHub"
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git \
      "${MANAGER_DIR}" || warn "ComfyUI-Manager: git clone failed"
  else
    log "ComfyUI-Manager already present"
  fi
  python3 -m pip install -r "${MANAGER_DIR}/requirements.txt" \
    || warn "ComfyUI-Manager: pip install requirements failed"
fi

# === ComfyUI-VideoHelperSuite (VHS) 自動導入 ===
if [ "${INSTALL_VHS}" = "1" ]; then
  VHS_DIR="${COMFY_ROOT}/custom_nodes/ComfyUI-VideoHelperSuite"
  if [ ! -d "${VHS_DIR}" ]; then
    log "Installing ComfyUI-VideoHelperSuite"
    git clone --depth=1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
      "${VHS_DIR}" || warn "VHS: git clone failed"
  else
    log "ComfyUI-VideoHelperSuite already present"
  fi
  python3 -m pip install -r "${VHS_DIR}/requirements.txt" \
    || warn "VHS: pip install requirements failed"
fi

# === モデルDL ===
if [ "${ALWAYS_DL}" = "1" ]; then
  if [ "${CLEAR_MODELS_BEFORE_DL}" = "1" ]; then
    log "wipe models/"
    rm -rf "${COMFY_ROOT}/models"/*
  fi
  # 必要なモデルフォルダを作成
  mkdir -p \
    "${COMFY_ROOT}"/models/{checkpoints,diffusion_models,text_encoders,vae,clip_vision}

  log "setup_models.sh (start)"
  /opt/bootstrap/setup_models.sh
  echo "[DONE] $(date)" >> "${WORKSPACE}/logs/setup_models.last.log"
  log "setup_models.sh (done)"
fi

# === Jupyter 起動 ===
declare -a JUPY_ARGS
if [ -n "${JUPYTER_TOKEN}" ]; then
  JUPY_ARGS+=(--ServerApp.token="${JUPYTER_TOKEN}")
else
  JUPY_ARGS+=(--ServerApp.token=)
fi

log "Starting Jupyter :${JUPYTER_PORT}"
nohup jupyter lab \
  --ip=0.0.0.0 --port="${JUPYTER_PORT}" --no-browser --allow-root \
  --ServerApp.root_dir="${WORKSPACE}" --ServerApp.allow_origin="*" \
  "${JUPY_ARGS[@]}" \
  > "${WORKSPACE}/logs/jupyter.log" 2>&1 &

log "Starting ComfyUI :${COMFY_PORT} from ${COMFY_ROOT}"
cd "${COMFY_ROOT}"
nohup python3 main.py \
  --listen 0.0.0.0 --port "${COMFY_PORT}" \
  > "${WORKSPACE}/logs/comfyui.log" 2&>1 &

# 軽いヘルス待ち
for i in {1..60}; do
  sleep 2
  curl -fsS "http://127.0.0.1:${COMFY_PORT}" >/dev/null 2>&1 && break || true
done

log "Jupyter:  http://<pod>:${JUPYTER_PORT}/$( [ -n "${JUPYTER_TOKEN}" ] && echo '?token='${JUPYTER_TOKEN} )"
log "ComfyUI:  http://<pod>:${COMFY_PORT}/"

exec tail -F "${WORKSPACE}/logs/comfyui.log" "${WORKSPACE}/logs/jupyter.log"
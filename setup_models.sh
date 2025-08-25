#!/usr/bin/env bash
set -euo pipefail
log(){ printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }

# ComfyUIのパスはentrypoint.shから環境変数で引き継ぐ
COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"

# RunPod ENV（必要なURLだけ設定すればDLされます）
WAN_I2V_URL="${WAN_I2V_URL:-}"
WAN_T2V_URL="${WAN_T2V_URL:-}"
WAN_VAE_URL="${WAN_VAE_URL:-}"
WAN_CLIPV_URL="${WAN_CLIPV_URL:-}"
WAN_TXTENC_URL="${WAN_TXTENC_URL:-}"

# 例：FLUX等（必要ならコメントアウト解除）
#FLUX_DEV_URL="${FLUX_DEV_URL:-}"
#FLUX_KONTEXT_URL="${FLUX_KONTEXT_URL:-}"
#FLUX_CLIP_L_URL="${FLUX_CLIP_L_URL:-}"
#FLUX_T5XXL_URL="${FLUX_T5XXL_URL:-}"
#FLUX_AE_URL="${FLUX_AE_URL:-}"

# aria2c / curl で「必ず指定名で保存」する
dl_into(){ 
  local url="${1:-}"; local dest="${2:-}"; local fname="${3:-}"
  [ -z "$url" ] && return 0
  [ -z "$dest" ] && return 0
  [ -z "$fname" ] && fname="$(basename "${url%%\?*}")"

  mkdir -p "$dest"
  log "DL -> ${dest}/${fname}  (${url})"

  if ! aria2c -x16 -s16 --min-split-size=1M --continue=true \
        --auto-file-renaming=false --allow-overwrite=true \
        ${HF_TOKEN:+--header="Authorization: Bearer ${HF_TOKEN}"} \
        -o "$fname" -d "$dest" "$url"; then
    curl -fL --retry 5 --retry-delay 2 \
      ${HF_TOKEN:+-H "Authorization: Bearer ${HF_TOKEN}"} \
      -o "${dest}/${fname}" "$url"
  fi

  if [[ "$fname" == *\?* ]]; then
    local clean="${fname%%\?*}"
    mv -f "${dest}/${fname}" "${dest}/${clean}" || true
    fname="$clean"
  fi

  [ -f "${dest}/${fname}" ] && printf '     -> %s (%s)\n' \
      "$fname" "$(du -h "${dest}/${fname}" | cut -f1)"
}

# ===== WAN 2.2 AIO（必要なURLのみ有効化） =====
dl_into "$WAN_I2V_URL"    "${COMFY_ROOT}/models/checkpoints"    "wan2.2-i2v-rapid-aio-v6.safetensors"
dl_into "$WAN_T2V_URL"    "${COMFY_ROOT}/models/checkpoints"    "wan2.2-t2v-rapid-aio-v6.safetensors"
dl_into "$WAN_VAE_URL"    "${COMFY_ROOT}/models/vae"            "Wan2.2_VAE.pth"
dl_into "$WAN_CLIPV_URL"  "${COMFY_ROOT}/models/clip_vision"    "clip_vision_vit_h.safetensors"
dl_into "$WAN_TXTENC_URL" "${COMFY_ROOT}/models/text_encoders"  "umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# ===== FLUX（必要時のみ） =====
#dl_into "$FLUX_DEV_URL"      "${COMFY_ROOT}/models/diffusion_models" "flux1-krea-dev.safetensors"
#dl_into "$FLUX_KONTEXT_URL"  "${COMFY_ROOT}/models/diffusion_models" "flux1-kontext-dev.safetensors"
#dl_into "$FLUX_CLIP_L_URL"   "${COMFY_ROOT}/models/text_encoders"    "clip_l.safetensors"
#dl_into "$FLUX_T5XXL_URL"    "${COMFY_ROOT}/models/text_encoders"    "t5xxl_fp16.safetensors"
#dl_into "$FLUX_AE_URL"       "${COMFY_ROOT}/models/vae"              "ae.safetensors"

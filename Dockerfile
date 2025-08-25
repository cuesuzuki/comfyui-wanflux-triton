# ベース：PyTorch + CUDA 12.1 ランタイム（RunPod/NVIDIA環境向け）
FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONUNBUFFERED=1 \
    WORKSPACE=/workspace \
    COMFY_PORT=8188 \
    JUPYTER_PORT=8888 \
    TORCH_CUDA_ARCH_LIST="8.9"

# 必要ツール・ライブラリ
RUN apt-get update && apt-get install -y --no-install-recommends \
      tini curl ca-certificates git ffmpeg aria2 \
      build-essential python3-dev \
    && rm -rf /var/lib/apt/lists/*

# JupyterLab
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir jupyterlab

# ディレクトリとログ領域
RUN mkdir -p /opt/bootstrap /usr/local/bin /workspace /runpod-volume /workspace/logs

# エントリポイント関連スクリプト配置
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY setup_models.sh /opt/bootstrap/setup_models.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/bootstrap/setup_models.sh

# ポート公開（ComfyUI / Jupyter）
EXPOSE 8188 8888

# Tini を subreaper として起動（ゾンビ回収の警告を抑制）
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["/usr/local/bin/entrypoint.sh"]

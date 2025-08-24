# ===== Base: CUDA 12.8 (for Triton) =====
ARG CUDA_TAG=12.8.1-cudnn-runtime-ubuntu22.04
FROM nvidia/cuda:${CUDA_TAG}

ARG DEBIAN_FRONTEND=noninteractive
ARG PYVER=3.11

# 基本ツール
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git git-lfs ffmpeg aria2 tini \
    build-essential pkg-config gnupg dirmngr procps \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# ===== Python ${PYVER} =====
RUN set -eux; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776' \
      | gpg --dearmor -o /etc/apt/keyrings/deadsnakes.gpg; \
    echo 'deb [signed-by=/etc/apt/keyrings/deadsnakes.gpg] http://ppa.launchpad.net/deadsnakes/ppa/ubuntu jammy main' \
      > /etc/apt/sources.list.d/deadsnakes-ppa.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends python${PYVER} python${PYVER}-dev python${PYVER}-venv; \
    ln -sf /usr/bin/python${PYVER} /usr/bin/python3; \
    curl -Ls https://bootstrap.pypa.io/get-pip.py | python3; \
    python3 -m pip install -U pip wheel setuptools; \
    rm -rf /var/lib/apt/lists/*

ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore
ENV LD_LIBRARY_PATH=/usr/local/lib/python3.11/dist-packages/torch/lib:${LD_LIBRARY_PATH}

# ===== PyTorch（cu128 build）+ Jupyter =====
RUN python3 -m pip install --index-url https://download.pytorch.org/whl/cu128 \
    torch torchvision torchaudio --upgrade \
 && python3 -m pip install jupyterlab

# ===== Triton + Sage Attention =====
RUN python3 -m pip install triton
RUN python3 -m pip install git+https://github.com/CicholGricenchos/Sage-Attention.git

# ===== スクリプト投入 =====
WORKDIR /opt
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY setup_models.sh /opt/bootstrap/setup_models.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/bootstrap/setup_models.sh

ENV ALWAYS_DL=1 \
    CLEAR_MODELS_BEFORE_DL=0 \
    INSTALL_MANAGER=1

EXPOSE 8188 8888

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/entrypoint.sh"]
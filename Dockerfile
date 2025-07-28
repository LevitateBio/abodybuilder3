# Use CUDA base image for GPU support
FROM nvidia/cuda:12.1.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CONDA_AUTO_UPDATE_CONDA=false
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    ca-certificates \
    python3 \
    python3-pip \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh

# Add conda to PATH
ENV PATH="/opt/conda/bin:$PATH"

# Accept conda Terms of Service for required channels
RUN conda config --set channel_priority flexible && \
    conda config --add channels conda-forge && \
    conda config --add channels pytorch && \
    conda config --add channels nvidia && \
    conda config --add channels bioconda

# Accept Terms of Service for default channels
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Copy environment files
COPY environment_gpu.yml /tmp/environment_gpu.yml
COPY environment_cpu.yml /tmp/environment_cpu.yml
COPY pinned-versions.txt /tmp/pinned-versions.txt

# Create conda environment (using GPU environment)
RUN conda env create -f /tmp/environment_gpu.yml --name abodybuilder3 --yes

# Activate conda environment
SHELL ["conda", "run", "-n", "abodybuilder3", "/bin/bash", "-c"]

# Copy project files
COPY pyproject.toml setup.py setup.cfg /app/
COPY src/ /app/src/

# Install the package in development mode
WORKDIR /app
ENV SETUPTOOLS_SCM_PRETEND_VERSION=0.1.0
RUN conda run -n abodybuilder3 pip install -e ".[dev]" --constraint /tmp/pinned-versions.txt

# Fix transformers/huggingface-hub compatibility issue
RUN conda run -n abodybuilder3 pip install --upgrade huggingface-hub>=0.21.0

# Set the default command to activate the conda environment
CMD ["conda", "run", "-n", "abodybuilder3", "/bin/bash"]

SHELL := /bin/bash

# Always run `hf` via pipx to avoid relying on local `hf` installations.
hf := pipx run --spec "huggingface_hub[cli]" hf

SNAP_NAME ?= inkling-2-mini
ENGINE ?= cpu

# Publisher repository of the model artifacts.
MODEL_REPO := ggml-org/Inkling-2-Mini-GGUF
MODEL_REF := e8a2cecf0e78

# llama.cpp release used to split the model into shards, matching the
# runtime pinned in snap/snapcraft.yaml.
LLAMA_CPP_TAG := b12650

.PHONY: all help init build install upload smoke-test install-deps init-submodules \
	download-models download-model-iq4-nl download-mmproj-q8-0 verify-models \
	split-model clean-model-original

all: help

#
# Main targets
#

help: ## Show this help message
	@echo "Usage: make <target>"
	@echo
	@echo "Targets:"
	@# List all targets with descriptions (lines starting with '##'):
	@grep -E '^[a-zA-Z0-9_-]+:.*## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'

init: init-submodules install-deps download-models split-model verify-models clean-model-original ## Initialize the build environment (dependencies, model weights, submodules, etc.)

build: ## Build the snap
	./dev/build.sh

install: ## Install the snap
	./dev/install.sh

upload: ## Upload the snap
	./dev/upload.sh

smoke-test: ## Run smoke tests (override with SNAP_NAME=... ENGINE=...)
	sudo ./dev/smoke-test.sh $(SNAP_NAME) $(ENGINE)

#
# Supporting targets
#

install-deps:
	@echo "Installing dependencies..."
	@# Ensure pipx is available for running the hf CLI.
	@command -v pipx >/dev/null 2>&1 || { \
		sudo apt-get update; \
		sudo apt-get install -y pipx; \
	}

init-submodules:
	@echo "Initializing submodules..."
	@if git submodule status | grep -q '^-'; then \
		git submodule update --init; \
	fi

# Download the model artifacts shipped with this snap:
#   - language model, imatrix-calibrated IQ4_NL quantization by ggml-org
#     (4-bit experts in layers 0-19, rest Q8_0; the source checkpoint is
#     natively NVFP4/MXFP8 so no post-training quantization is involved)
#   - vision projector (mmproj), Q8_0
download-models: download-model-iq4-nl download-mmproj-q8-0

download-model-iq4-nl:
	@echo "Downloading Inkling 2 Mini language model (IQ4_NL)..."
	$(hf) download $(MODEL_REPO) Inkling-2-Mini-IQ4_NL.gguf \
		--revision $(MODEL_REF) \
		--local-dir model-weights/model-inkling-2-mini-iq4-nl

download-mmproj-q8-0:
	@echo "Downloading Inkling 2 Mini vision projector (Q8_0)..."
	$(hf) download $(MODEL_REPO) mmproj-Inkling-2-Mini-Q8_0.gguf \
		--revision $(MODEL_REF) \
		--local-dir model-weights/mmproj-inkling-2-mini-q8-0

# The IQ4_NL GGUF is ~17.6 GB: split it into shards so each fits
# comfortably in a snap component (< ~5 GB), following the
# qwen3-coder-snap pattern. With --split-max-size 4500M the chunky MoE
# tensor boundaries yield 5 shards (~4.3 GB each + a 0.7 GB tail).
# llama-server only needs the path of the first shard.
split-model: ## Split the downloaded model into component-sized shards
	@echo "Splitting the model into 4 shards..."
	@test -f model-weights/model-inkling-2-mini-iq4-nl/Inkling-2-Mini-IQ4_NL.gguf || { \
		echo "Model not found. Run 'make download-model-iq4-nl' first." >&2; exit 1; \
	}
	@if [ ! -x /tmp/llamacpp-split-$(LLAMA_CPP_TAG)/llama-$(LLAMA_CPP_TAG)/llama-gguf-split ]; then \
		mkdir -p /tmp/llamacpp-split-$(LLAMA_CPP_TAG) && \
		curl -sL "https://github.com/ggml-org/llama.cpp/releases/download/$(LLAMA_CPP_TAG)/llama-$(LLAMA_CPP_TAG)-bin-ubuntu-x64.tar.gz" | \
			tar -xz -C /tmp/llamacpp-split-$(LLAMA_CPP_TAG); \
	fi
	rm -f model-weights/model-inkling-2-mini-iq4-nl/Inkling-2-Mini-IQ4_NL-*-of-0000*.gguf
	/tmp/llamacpp-split-$(LLAMA_CPP_TAG)/llama-$(LLAMA_CPP_TAG)/llama-gguf-split \
		--split \
		--split-max-size 4500M \
		model-weights/model-inkling-2-mini-iq4-nl/Inkling-2-Mini-IQ4_NL.gguf \
		model-weights/model-inkling-2-mini-iq4-nl/Inkling-2-Mini-IQ4_NL
	@# Keep the unsplit file out of the packaging part, and keep the shards
	@# named as expected by snapcraft.yaml.
	@ls -lh model-weights/model-inkling-2-mini-iq4-nl/

# The unsplit GGUF (~17.6 GB) is fully represented by the shards produced
# above and is re-downloadable at the pinned revision; drop it so that
# disk-constrained environments (e.g. standard GitHub-hosted CI runners,
# with ~45 GB free after reclaiming preinstalled toolchains) can hold both
# the model-weights tree and the component packages.
clean-model-original:
	@rm -f model-weights/model-inkling-2-mini-iq4-nl/Inkling-2-Mini-IQ4_NL.gguf

verify-models: ## Verify downloaded artifacts (sha256, computed at pinned revision)
	@echo "Verifying model checksums..."
	@cd model-weights && sha256sum -c SHA256SUMS

# Inkling 2 Mini inference snap
[![inkling-2-mini](https://snapcraft.io/inkling-2-mini/badge.svg)](https://snapcraft.io/inkling-2-mini)

Inkling 2 Mini is a multimodal looped-transformer model from Thinking Machines Lab: a Mixture-of-Experts with 26.4B total parameters, 3.4B active per token, where the middle 12 of its 24 layers run three times per token. It understands images as well as text, supports a 1M-token context, calls tools natively and reasons with a controllable reasoning effort before it answers.

Use this snap to quickly install an optimized environment for local inference with Inkling 2 Mini.

The snap includes the following hardware-optimized inference engines:

* cpu: Optimized for x64 and ARM (armv8, armv9) CPUs
* vulkan: Vulkan GPU acceleration for AMD and Intel GPUs

The most suitable engine is automatically selected based on the available hardware.

#### Install
```
sudo snap install inkling-2-mini
```

#### Run
```
inkling-2-mini
```

> [!TIP]
> Some accelerators require extra [drivers](https://documentation.ubuntu.com/inference-snaps/how-to/setup/drivers/) to be usable with this snap.

## Resources

📚 **[Documentation](https://documentation.ubuntu.com/inference-snaps/)**, learn how to use inference snaps

💬 **[Discussions](https://github.com/canonical/inference-snaps/discussions)**, ask questions and share ideas

🐛 **[Issues](https://github.com/canonical/inference-snaps/issues)**, report bugs and request features

## Build and install from source

Clone the repo:
```shell
git clone https://github.com/canonical/inkling-2-mini-snap
cd inkling-2-mini-snap
```

Initialize the development environment:
```shell
make init
```

Build and install snap:
```shell
make build
make install
```

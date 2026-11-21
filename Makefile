.PHONY: help build build-pipewire build-sendspin build-squeezelite push load-versions

TAG ?= latest
PLATFORM ?= linux/amd64,linux/arm64
REGISTRY ?= ghcr.io/howels
LOAD_VERSIONS := set -a && . ./versions.env && set +a

ifneq ($(PLATFORM),)
PLATFORM_ARG := --platform $(PLATFORM)
endif

help:
	@echo "Targets: build, build-pipewire, build-sendspin, build-squeezelite, push"
	@echo "TAG=$(TAG) PLATFORM=$(PLATFORM) REGISTRY=$(REGISTRY)"

load-versions:
	@:

build-pipewire:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg ALPINE_VERSION="$$ALPINE_VERSION" \
	  --manifest "$(REGISTRY)/pipewire:$(TAG)" \
	  pipewire

build-sendspin:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg DEBIAN_VERSION="$$DEBIAN_VERSION" \
	  --build-arg SENDSPIN_CLI_REF="$$SENDSPIN_CLI_REF" \
	  --manifest "$(REGISTRY)/sendspin:$(TAG)" \
	  sendspin

build-squeezelite:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg ALPINE_VERSION="$$ALPINE_VERSION" \
	  --build-arg SQUEEZELITE_REF="$$SQUEEZELITE_REF" \
	  --manifest "$(REGISTRY)/squeezelite:$(TAG)" \
	  squeezelite

build: build-pipewire build-sendspin build-squeezelite

push: build
	@for name in pipewire sendspin squeezelite; do \
	  echo "==> push $(REGISTRY)/$$name:$(TAG)"; \
	  podman manifest push --all "$(REGISTRY)/$$name:$(TAG)" \
	    "docker://$(REGISTRY)/$$name:$(TAG)"; \
	done

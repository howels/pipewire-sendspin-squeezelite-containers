.PHONY: help build build-pipewire build-sendspin build-squeezelite push smoke load-versions

TAG ?= latest
PLATFORM ?= linux/amd64
REGISTRY ?= ghcr.io/howels
SMOKE_PREFIX ?= localhost
LOAD_VERSIONS := set -a && . ./versions.env && set +a

ifneq ($(PLATFORM),)
PLATFORM_ARG := --platform $(PLATFORM)
endif

help:
	@echo "Targets: build, build-pipewire, build-sendspin, build-squeezelite, push, smoke"
	@echo "TAG=$(TAG) PLATFORM=$(PLATFORM) REGISTRY=$(REGISTRY)"

load-versions:
	@:

build-pipewire:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg ALPINE_VERSION="$$ALPINE_VERSION" \
	  -t "$(SMOKE_PREFIX)/pipewire:$(TAG)" \
	  pipewire

build-sendspin:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg DEBIAN_VERSION="$$DEBIAN_VERSION" \
	  --build-arg SENDSPIN_CLI_REF="$$SENDSPIN_CLI_REF" \
	  -t "$(SMOKE_PREFIX)/sendspin:$(TAG)" \
	  sendspin

build-squeezelite:
	@$(LOAD_VERSIONS); \
	podman build $(PLATFORM_ARG) \
	  --build-arg ALPINE_VERSION="$$ALPINE_VERSION" \
	  --build-arg SQUEEZELITE_REF="$$SQUEEZELITE_REF" \
	  -t "$(SMOKE_PREFIX)/squeezelite:$(TAG)" \
	  squeezelite

build: build-pipewire build-sendspin build-squeezelite

smoke:
	TAG='$(TAG)' PREFIX='$(SMOKE_PREFIX)' ./scripts/smoke.sh

push: build
	@for name in pipewire sendspin squeezelite; do \
	  echo "==> push $(REGISTRY)/$$name:$(TAG)"; \
	  podman push "$(SMOKE_PREFIX)/$$name:$(TAG)" \
	    "docker://$(REGISTRY)/$$name:$(TAG)"; \
	done

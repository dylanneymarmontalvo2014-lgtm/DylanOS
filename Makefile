# Atajos seguros y reproducibles para las tareas documentadas de DylanOS.
SHELL := /bin/bash
.DEFAULT_GOAL := help
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PYTHON ?= python3
PROFILE ?= development
RESUME ?= 0
BUILD_JOBS ?= $(shell n=$$(nproc 2>/dev/null || echo 2); if [ $$n -gt 4 ]; then echo 4; else echo $$n; fi)
BUILD_ARGS :=

ifeq ($(PROFILE),development)
else ifeq ($(PROFILE),default)
BUILD_ARGS += --minimal
else ifeq ($(PROFILE),minimal)
BUILD_ARGS += --minimal
else
$(error PROFILE debe ser development, default o minimal)
endif

ifneq ($(filter 0 1,$(RESUME)),$(RESUME))
$(error RESUME debe ser 0 o 1)
endif
ifeq ($(RESUME),1)
BUILD_ARGS += --resume
endif

.PHONY: help installer check build iso test-iso iso-validated qemu-test

help:
	@echo "DylanOS — tareas disponibles:"
	@echo "  make check                 Comprobaciones, pruebas y QA QML"
	@echo "  make installer             Compila el frontend del instalador"
	@echo "  make build                 Construye el chroot (PROFILE=development|minimal)"
	@echo "  make build RESUME=1        Reanuda un chroot existente"
	@echo "  make build BUILD_JOBS=2    Limita los trabajos CMake (por defecto hasta 4)"
	@echo "  make iso                   Genera la ISO desde un build completo"
	@echo "  make test-iso              Valida checksum y estructura de la ISO"
	@echo "  make iso-validated         Build + ISO + validación, en secuencia"
	@echo "  make qemu-test             Ejecuta la prueba de arranque en QEMU"

installer:
	cd "$(ROOT)" && bash scripts/build-installer.sh

check:
	cd "$(ROOT)" && DYLANOS_PYTHON="$(PYTHON)" bash scripts/check.sh

build:
	cd "$(ROOT)" && DYLANOS_BUILD_JOBS="$(BUILD_JOBS)" bash scripts/build.sh $(BUILD_ARGS)

iso:
	cd "$(ROOT)" && bash scripts/iso.sh

test-iso:
	cd "$(ROOT)" && bash scripts/test.sh

iso-validated:
	$(MAKE) build PROFILE="$(PROFILE)" RESUME="$(RESUME)" BUILD_JOBS="$(BUILD_JOBS)"
	$(MAKE) iso
	$(MAKE) test-iso

qemu-test:
	cd "$(ROOT)" && bash scripts/test_QEMU.sh

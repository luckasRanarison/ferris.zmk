.PHONY: build build/central clean reset flash

ZMK_DIR ?= /workspaces/zmk/app
ZMK_CONFIG_DIR = /workspaces/zmk-config
ZMK_CONFIG_LABEL = zmk-config
BOARD = nice_nano_v2

CONTAINER := $(shell \
  docker ps -q | while read cid; do \
    if docker inspect $$cid --format '{{range .Mounts}}{{.Name}}{{println}}{{end}}' | grep -q '^$(ZMK_CONFIG_LABEL)$$'; then \
      docker inspect --format '{{.Name}}' $$cid; \
      break; \
    fi; \
  done)

DOCKER_RUN = docker exec -w $(ZMK_CONFIG_DIR) -it $(CONTAINER)

build: build/central build/left build/right build/reset

build/central:
	$(MAKE) build-part SHIELD="ferris_central dongle_display" \
		BUILD_DIR=build/central \
		EXTRA_ARGS="-S studio-rpc-usb-uart" \
		EXTRA_CMAKE_ARGS="-DCONFIG_ZMK_STUDIO=y -DCONFIG_ZMK_STUDIO_LOCKING=n"

build/left:
	$(MAKE) build-part SHIELD=ferris_left BUILD_DIR=build/left

build/right:
	$(MAKE) build-part SHIELD=ferris_right BUILD_DIR=build/right

build/reset:
	$(MAKE) build-part SHIELD=settings_reset BUILD_DIR=build/reset

build-part:
	@echo "Building $(PART) with shield $(SHIELD) in $(BUILD_DIR) from root $(ZMK_DIR)"

	$(DOCKER_RUN) bash -c "\
		source ~/.bashrc && \
		west build -s $(ZMK_DIR) -d $(BUILD_DIR) -b $(BOARD) $(EXTRA_ARGS) -- \
	  -DSHIELD=$(SHIELD) \
	  -DZMK_CONFIG=$(ZMK_CONFIG_DIR)/config \
	  -DZMK_EXTRA_MODULES=$(ZMK_CONFIG_DIR) \
		$(EXTRA_CMAKE_ARGS)"

reset:
	@cp ./build/reset/zephyr/zmk.uf2 /run/media/$$USER/NICENANO

flash:
	$(MAKE) flash-part PART=central

flash-left:
	$(MAKE) flash-part PART=left

flash-right:
	$(MAKE) flash-part PART=right

flash-part:
	@cp ./build/$(PART)/zephyr/zmk.uf2 /run/media/$$USER/NICENANO

clean:
	$(DOCKER_RUN) rm -rf ./build

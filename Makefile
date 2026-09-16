DUB_FLAGS = --quiet --arch wasm32-unknown-unknown-wasm --build release
ifneq ($(origin WASI_SDK_PATH), undefined)
	override DUB_FLAGS += --config wasi
endif

# Just rebuild every time because it's fast.
# cart.wasm: Makefile dub.json $(wildcard source/*.d)
build:
	dub build ${DUB_FLAGS}

run: build
	w4 run cart.wasm

run-native: build
	w4 run-native cart.wasm

html: build
	w4 bundle cart.wasm --html index.html --title "Game Boy Music Sequencer"

watch:
	w4 watch

clean:
	rm -rf cart.wasm index.html .dub

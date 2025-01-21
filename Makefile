.PHONY: format
format:
	./scripts/formatter.sh

.PHONY: build
build:
	./scripts/build_venv.sh "build_venv"

.PHONY: compile
compile:
	./scripts/compile_binary.sh

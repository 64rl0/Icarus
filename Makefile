.PHONY: deploy
deploy:
	./scripts/deploy.sh

.PHONY: build-launcher
build-launcher:
	./scripts/build_launcher_binary.sh

.PHONY: build-runtime
build-runtime:
	./scripts/build_runtime.sh

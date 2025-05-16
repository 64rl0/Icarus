.PHONY: build
build:
	./scripts/build_venv.sh "build_venv"

.PHONY: format
format:
	./scripts/formatter.sh

.PHONY: release
release:
	./scripts/release.sh

.PHONY: test
test:
	./scripts/test.sh

.PHONY: deploy
deploy:
	./scripts/deploy.sh

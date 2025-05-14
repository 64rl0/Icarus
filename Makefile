.PHONY: format
format:
	./scripts/formatter/formatter.sh

.PHONY: build
build:
	./scripts/build_venv.sh "build_venv"

.PHONY: release
release:
	./scripts/release.sh

.PHONY: test
test:
	./scripts/test.sh

.PHONY: deploy
deploy:
	./scripts/deploy.sh

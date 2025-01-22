.PHONY: format
format:
	./scripts/formatter.sh

.PHONY: build
build:
	./scripts/build_venv.sh "build_venv"

.PHONY: deploy
deploy:
	./scripts/deploy.sh

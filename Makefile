.PHONY: build test install package clean

PREFIX ?= /usr/local

build:
	./scripts/build-cli.sh release

test:
	./scripts/check.sh

install:
	./scripts/install-cli.sh "$(PREFIX)"

package:
	./scripts/package-cli.sh

clean:
	swift package clean

SCRATCH_PATH ?= $(HOME)/Library/Caches/display-restore-build

build:
	swift build --scratch-path "$(SCRATCH_PATH)"

test:
	swift test --scratch-path "$(SCRATCH_PATH)"

run:
	swift run --scratch-path "$(SCRATCH_PATH)" DisplayRestoreApp

SCRATCH_PATH ?= $(HOME)/Library/Caches/layoutrecall-build

build:
	swift build --scratch-path "$(SCRATCH_PATH)"

test:
	swift test --no-parallel --scratch-path "$(SCRATCH_PATH)"

run:
	swift run --scratch-path "$(SCRATCH_PATH)" LayoutRecallApp

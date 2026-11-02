SHELL := /bin/bash

XCODE_DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SIMULATOR ?= iPhone 17
PROJECT := StatsWorkout.xcodeproj
SCHEME := StatsWorkout

.PHONY: help generate build test open clean simulator select-xcode

help:
	@echo "make generate    - regenerate $(PROJECT) from project.yml (XcodeGen)"
	@echo "make open        - generate and open the project in Xcode"
	@echo "make build       - build for the iOS simulator"
	@echo "make test        - run unit tests on the iOS simulator"
	@echo "make select-xcode- point xcode-select at a full Xcode installation"
	@echo "make clean       - remove build products"

generate:
	xcodegen generate

open: generate
	open $(PROJECT)

build: generate
	DEVELOPER_DIR=$(XCODE_DEVELOPER_DIR) xcodebuild build \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-quiet

test: generate
	DEVELOPER_DIR=$(XCODE_DEVELOPER_DIR) xcodebuild test \
		-project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-quiet

select-xcode:
	sudo xcode-select -s $(XCODE_DEVELOPER_DIR)

clean:
	rm -rf build DerivedData

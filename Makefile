SHELL := /bin/bash

XCODE_DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SIMULATOR ?= iPhone 17
TEAM_ID ?= B592D69P29
BUILD_NUMBER ?=
PROJECT := StatsWorkout.xcodeproj
SCHEME := StatsWorkout

.PHONY: help generate build test open clean select-xcode testflight deploy-site shots shots-cs

help:
	@echo "make generate    - regenerate $(PROJECT) from project.yml (XcodeGen)"
	@echo "make open        - generate and open the project in Xcode"
	@echo "make build       - build for the iOS simulator"
	@echo "make test        - run unit tests on the iOS simulator"
	@echo "make select-xcode- point xcode-select at a full Xcode installation"
	@echo "make testflight  - archive and upload a build to TestFlight"
	@echo "make deploy-site - publish Website/ to stats-workout.ondralinek.cz"
	@echo "make shots       - capture the App Store screenshots (English) from clean simulators"
	@echo "make shots-cs    - the same frames with the app in Czech"
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

testflight:
	TEAM_ID=$(TEAM_ID) BUILD_NUMBER=$(BUILD_NUMBER) ./Scripts/publish-testflight.sh

deploy-site:
	./Scripts/deploy-site.sh

shots:
	./Scripts/capture-screenshots.sh all en

shots-cs:
	./Scripts/capture-screenshots.sh all cs

shots-iphone:
	./Scripts/capture-screenshots.sh iphone en

shots-ipad:
	./Scripts/capture-screenshots.sh ipad en

clean:
	rm -rf build DerivedData

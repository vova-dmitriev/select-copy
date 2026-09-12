.PHONY: project test build format lint install-local

project:
	xcodegen generate

test: project
	xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS'

build: project
	xcodebuild build -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Debug -destination 'platform=macOS'

format:
	swiftformat SelectCopy SelectCopyTests SelectCopyUITests

lint:
	swiftlint lint --strict

install-local:
	bash scripts/install-local.sh

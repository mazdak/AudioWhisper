.PHONY: help build build-notarize test clean update-brew-cask publish-brew-cask release

SCRIPTS := scripts

# Default target
help:
	@echo "AudioWhisper Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build              - Build the release app bundle"
	@echo "  build-notarize     - Build and notarize the app"
	@echo "  test               - Run tests"
	@echo "  clean              - Clean build artifacts"
	@echo "  update-brew-cask   - Update Homebrew cask formula with latest release"
	@echo "  publish-brew-cask  - Update and publish cask to tap repository"
	@echo "  release            - Create a new GitHub release"

# Build the app
build:
	$(SCRIPTS)/build.sh

# Build and notarize the app
build-notarize:
	$(SCRIPTS)/build.sh --notarize

# Run tests
test:
	$(SCRIPTS)/run-tests.sh

# Clean build artifacts
clean:
	rm -rf .build
	rm -rf AudioWhisper.app
	rm -f AudioWhisper.zip
	rm -f Sources/AudioProcessorCLI

# Update the Homebrew cask formula with latest GitHub release
update-brew-cask:
	@echo "Updating Homebrew cask formula..."
	$(SCRIPTS)/update-brew-cask.sh

# Update and publish the cask to the tap repository
publish-brew-cask: update-brew-cask
	@echo "Publishing to tap repository..."
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	if [ -d "../homebrew-tap" ]; then \
		cd ../homebrew-tap && \
		git add Casks/audiowhisper.rb && \
		git diff --cached --quiet || (git commit -m "Update AudioWhisper to v$$VERSION" && git push); \
		echo "✅ Published to homebrew-tap"; \
	else \
		echo "❌ Error: homebrew-tap repository not found at ../homebrew-tap"; \
		echo "Please clone it first: git clone https://github.com/mazdak/homebrew-tap.git ../homebrew-tap"; \
		exit 1; \
	fi

# Create a new release
release:
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	echo "Creating release v$$VERSION..."; \
	if git diff --quiet && git diff --cached --quiet; then \
		$(SCRIPTS)/build.sh && \
		zip -r AudioWhisper.zip AudioWhisper.app && \
		gh release create "v$$VERSION" AudioWhisper.zip --title "v$$VERSION" --generate-notes && \
		echo "✅ Release v$$VERSION created"; \
	else \
		echo "❌ Error: Working directory is not clean. Commit or stash changes first."; \
		exit 1; \
	fi

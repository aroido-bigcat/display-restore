# LayoutRecall

LayoutRecall is a macOS menu bar utility that watches for external display reconfiguration and restores a saved layout when macOS scrambles identical monitors.

This repository is published as open source under the MIT license.

## Why this repo exists

The initial scope follows the product draft:

- menu bar app
- live display snapshot capture
- display change debounce
- saved layout profiles
- safe profile matching
- automatic restore when confidence is high
- one-click fallback with `Fix Now` and `Swap Left / Right`
- persisted diagnostics and launch-at-login integration

## Repository layout

- `Package.swift`: Swift package entry point
- `Sources/LayoutRecallApp`: SwiftUI menu bar shell
- `Sources/LayoutRecallKit`: domain models and restore pipeline scaffolding
- `Tests/LayoutRecallKitTests`: matcher-focused unit tests
- `docs/PRD.md`: condensed build summary from the planning document
- `docs/SPEC.md`: detailed product specification and delivery roadmap

## Local development

```bash
git clone https://github.com/aroido-bigcat/layoutrecall.git
cd layoutrecall
make build
make test
```

The repository uses a scratch build path in `~/Library/Caches` to avoid Swift index-store rename failures when the checkout lives on slower or externally mounted volumes.

Open `Package.swift` in Xcode if you want an IDE workflow. The current app target now includes the live snapshot, event monitoring, restore execution, verification, diagnostics, and settings pipeline, but it is still early-stage software.

## Runtime notes

- Automatic restore and manual restore actions require `displayplacer` to be installed and available on `PATH`.
- Build and test do not require `displayplacer`.
- The current implementation targets the common two external display workflow first, especially the identical-monitor left/right swap problem.

## Release updates

- The app checks GitHub Releases for `aroido-bigcat/layoutrecall` and can prompt the user to update or skip a specific version.
- Automatic checks can be turned off from `General > Updates`.
- To build a release archive for GitHub Releases, run:

```bash
./scripts/build-release-archive VERSION=0.1.0
```

- Upload the generated ZIP asset from `dist/releases/` to the matching GitHub Release so in-app updates can download it.

## License

MIT. See `LICENSE`.

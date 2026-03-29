# Display Restore

Display Restore is a macOS menu bar utility that watches for external display reconfiguration and restores a saved layout when macOS scrambles identical monitors.

This repository is published as open source under the MIT license.

## Why this repo exists

The initial scope follows the product draft:

- menu bar app
- display change debounce
- saved layout profiles
- safe profile matching
- automatic restore when confidence is high
- one-click fallback with `Fix Now` and `Swap Left / Right`

## Repository layout

- `Package.swift`: Swift package entry point
- `Sources/DisplayRestoreApp`: SwiftUI menu bar shell
- `Sources/DisplayRestoreKit`: domain models and restore pipeline scaffolding
- `Tests/DisplayRestoreKitTests`: matcher-focused unit tests
- `docs/PRD.md`: condensed build summary from the planning document

## Local development

```bash
git clone https://github.com/aroido-bigcat/display-restore.git
cd display-restore
make build
make test
```

The repository uses a scratch build path in `~/Library/Caches` to avoid Swift index-store rename failures when the checkout lives on slower or externally mounted volumes.

Open `Package.swift` in Xcode if you want an IDE workflow. The current app target is a working scaffold, not a finished product.

## License

MIT. See `LICENSE`.

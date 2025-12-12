## Features

- API-only interface for GTP command handling
- Bundled Core ML models for strongest 28b and human SL networks
- Model-only inference (no search yet)
- 19x19 board with Chinese rules (area scoring, positional ko, no suicide)
- Text-based status reporting for testing

## Usage

```swift
import KataGoOnAppleSilicon

// Create board
let board = Board()
board.playMove(at: Point(x: 3, y: 3), stone: .black)

// Load model
let katago = KataGoInference()
try katago.loadModel(for: "AI")

// Create board state for inference
let boardState = BoardState(board: board)

// Predict
let output = try katago.predict(board: boardState, profile: "AI")

// GTP handling
let gtp = GTPHandler(katago: katago)
let response = gtp.handleCommand("genmove white")
print(response)  // "= D4\n\n"
```

## Requirements

- macOS 12.0+
- Apple Silicon (M1/M2+)

## Building

```bash
swift build
swift test
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Model Files

The Core ML model files are not included in this repository due to their size (~191MB total). Download them separately from the [releases](https://github.com/ChinChangYang/KataGo/releases/tag/v1.16.4-coreml1) and place them in `Sources/KataGoOnAppleSilicon/Models/Resources/`.
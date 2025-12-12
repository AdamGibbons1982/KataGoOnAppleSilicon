import CoreML

/// Represents the board state for model input
public struct BoardState {
    public let spatial: MLMultiArray  // [1,22,19,19]
    public let global: MLMultiArray   // [1,19]
    
    public init(spatial: MLMultiArray, global: MLMultiArray) {
        self.spatial = spatial
        self.global = global
    }
    
    /// Create from board data (placeholder)
    public init(board: Board, komi: Float = 7.5, turnNumber: Int = 0) {
        // KataGo features: 22 planes
        let spatialShape: [NSNumber] = [1, 22, 19, 19]
        self.spatial = try! MLMultiArray(shape: spatialShape, dataType: .float16)
        
        // Basic implementation: planes 0-1 for stones
        for y in 0..<19 {
            for x in 0..<19 {
                let stone = board.stones[y][x]
                if stone == .black {
                    spatial[[0, 0, NSNumber(value: y), NSNumber(value: x)]] = 1.0
                } else if stone == .white {
                    spatial[[0, 1, NSNumber(value: y), NSNumber(value: x)]] = 1.0
                }
                // Other planes: 0 for now
            }
        }
        
        let globalShape: [NSNumber] = [1, 19]
        self.global = try! MLMultiArray(shape: globalShape, dataType: .float16)
        // Fill global with zeros for now
        for i in 0..<19 {
            self.global[i] = 0.0
        }
        // Set some defaults if needed
        // self.global[5] = NSNumber(value: komi / 20.0)  // komi
    }
}

/// Represents the model output
public struct ModelOutput {
    public let policy: MLMultiArray  // [1, 19, 19]
    public let value: Float           // scalar
    public let ownership: MLMultiArray  // [1, 19, 19]
    
    public init(policy: MLMultiArray, value: Float, ownership: MLMultiArray) {
        self.policy = policy
        self.value = value
        self.ownership = ownership
    }
}
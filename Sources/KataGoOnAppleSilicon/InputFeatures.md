# KataGo Neural Network Input Features (V7)

This document describes the input features used by the KataGo neural network model.
The feature encoding follows the `fillRowV7()` function from KataGo's [nninputs.cpp](https://github.com/ChinChangYang/KataGo/blob/metal-coreml-stable/cpp/neuralnet/nninputs.cpp).

## Overview

- **Spatial Features**: 22 planes of shape `[1, 22, 19, 19]`
- **Global Features**: 19 scalar values of shape `[1, 19]`

---

## Algorithm Overview

The `fillRowV7()` function from KataGo's `nninputs.cpp` implements the feature encoding algorithm. The algorithm follows a specific order to fill both spatial and global features:

1. **Initialization**: All feature arrays are initialized (spatial features default to 0.0, except plane 0 which is explicitly set to 1.0)

2. **Spatial Features Filling** (22 planes, processed in order):
   - Plane 0: On-board indicator (always 1.0)
   - Planes 1-2: Stone positions (perspective-based)
   - Planes 3-5: Liberty counts (1, 2, or 3 liberties)
   - Plane 6: Ko-ban locations
   - Planes 7-8: Encore features (zero for Chinese rules)
   - Planes 9-13: Move history (with nested conditionals)
   - Planes 14-17: Ladder detection features
   - Planes 18-19: Area ownership
   - Planes 20-21: Encore stones (zero for Chinese rules)

3. **Global Features Filling** (19 values):
   - Features 0-4: Pass history (set during spatial history filling)
   - Features 5-18: Computed based on game state, rules, and komi

**Key Dependencies**:
- History filling (planes 9-13) sets global features 0-4 for pass moves
- Global feature 5 (komi) requires perspective-aware calculation
- Global feature 14 (pass ends phase) requires complex ko hash and pass history analysis
- Global feature 18 (komi parity wave) requires komi calculation from feature 5

**Chinese Rules Simplifications**:
- Many features are zero-initialized (planes 7-8, 20-21, global features 6-7, 10-13, 15-17)
- Simplified history tracking (no game end or phase end logic)
- Simple ko rule (no positional/situational ko)
- Area scoring instead of territory scoring

---

## Spatial Features (22 Planes)

Each plane is a 19x19 binary or float grid where position `(y, x)` corresponds to the board intersection.

| Plane | Name | Description |
|-------|------|-------------|
| 0 | On board | 1.0 for all valid board positions |
| 1 | Own stones | 1.0 where current player (pla) has a stone |
| 2 | Opponent stones | 1.0 where opponent (opp) has a stone |
| 3 | 1 liberty | 1.0 where stones have exactly 1 liberty (atari) |
| 4 | 2 liberties | 1.0 where stones have exactly 2 liberties |
| 5 | 3 liberties | 1.0 where stones have exactly 3 liberties |
| 6 | Ko-ban | 1.0 at ko prohibition locations (including superko) |
| 7 | Ko recapture blocked | 1.0 at encore ko recapture blocked locations |
| 8 | (Reserved) | Encore-specific feature |
| 9 | Move 1 ago | 1.0 at the location of the most recent move (by opponent) |
| 10 | Move 2 ago | 1.0 at the location of 2 moves ago (by pla) |
| 11 | Move 3 ago | 1.0 at the location of 3 moves ago (by opp) |
| 12 | Move 4 ago | 1.0 at the location of 4 moves ago (by pla) |
| 13 | Move 5 ago | 1.0 at the location of 5 moves ago (by opp) |
| 14 | Ladder captured | 1.0 where stones would be captured in a ladder |
| 15 | Ladder (prev board) | Ladder status from previous board state |
| 16 | Ladder (prev prev) | Ladder status from 2 boards ago |
| 17 | Ladder escape | 1.0 at moves that escape/capture a ladder |
| 18 | Area (own) | 1.0 where current player owns territory/area |
| 19 | Area (opp) | 1.0 where opponent owns territory/area |
| 20 | Encore stones (own) | Second encore starting stones for pla (Japanese rules) |
| 21 | Encore stones (opp) | Second encore starting stones for opp (Japanese rules) |

### Notes on Spatial Features

- **Perspective**: Planes 1-2 are relative to the current player, not absolute black/white.
  - If it's Black's turn: plane 1 = black stones, plane 2 = white stones
  - If it's White's turn: plane 1 = white stones, plane 2 = black stones

- **On Board Feature**: Plane 0 is always 1.0 for all 19x19 positions. This helps the network distinguish valid positions.

- **Liberty Features**: Planes 3-5 indicate stones with 1, 2, or 3 liberties. Stones with 4+ liberties have no feature set.
  
- **Move History**: Planes 9-13 indicate where the last 5 moves were played.
  - Pass moves set the corresponding **global** feature instead (features 0-4).
  - History alternates: opp move, pla move, opp move, pla move, opp move.
  
- **Chinese Rules Simplification**: For Chinese rules (area scoring), many planes are zeros or simplified:
  - Planes 7-8: No encore features (Chinese rules have no encore)
  - Planes 18-19: Area features (computed based on area scoring)
  - Planes 20-21: No encore starting stones

### Spatial Features Filling Algorithm

The algorithm fills spatial features in the following order, based on `fillRowV7()`:

#### Plane 0: On Board
- **Algorithm**: Iterate over all 19×19 positions and set each to 1.0
- **Purpose**: Provides a constant mask indicating valid board positions
- **Implementation**: Simple nested loop over y and x coordinates

#### Planes 1-2: Stone Positions
- **Algorithm**: 
  1. Determine `pla` (current player) and `opp` (opponent) based on `nextPlayer`
  2. Iterate over all board positions
  3. For each position:
     - If stone == `pla`: set plane 1 to 1.0
     - If stone == `opp`: set plane 2 to 1.0
     - If empty: both planes remain 0.0
- **Perspective**: Features are relative to the current player, not absolute black/white
- **Note**: This perspective-based encoding helps the network learn position-independent patterns

#### Planes 3-5: Liberty Counts
- **Algorithm**:
  1. Iterate over all board positions
  2. For each non-empty position:
     - Calculate liberty count using `board.liberties(of: Point)`
     - If liberty count == 1: set plane 3 to 1.0
     - If liberty count == 2: set plane 4 to 1.0
     - If liberty count == 3: set plane 5 to 1.0
     - If liberty count >= 4: no plane is set (remains 0.0)
- **Purpose**: Indicates stones in atari (1 liberty) or with few liberties (2-3)
- **Note**: Only stones with 1-3 liberties are marked; stones with 4+ liberties have no feature

#### Plane 6: Ko-ban
- **Algorithm**:
  1. Check if `board.koPoint` exists
  2. If ko point exists: set plane 6 at ko point location to 1.0
  3. Otherwise: plane 6 remains 0.0 everywhere
- **Purpose**: Marks ko prohibition locations
- **Note**: For Chinese rules (simple ko), only one ko point can exist at a time

#### Planes 7-8: Encore Features
- **Algorithm**: Zero-initialized (no explicit setting needed)
- **Purpose**: Reserved for encore phase features (Japanese rules)
- **Chinese Rules**: Always 0.0 (no encore phase in Chinese rules)

#### Planes 9-13: Move History
- **Algorithm**: See [History Filling Algorithm](#history-filling-algorithm-planes-9-13) below for detailed description
- **Overview**:
  1. Determine `maxTurnsOfHistoryToInclude` (5 for Chinese rules)
  2. Calculate `amountOfHistoryToTryToUse = min(maxTurnsOfHistoryToInclude, moveHistoryLen)`
  3. Use nested conditionals to check each move in reverse chronological order
  4. Pattern: opp (plane 9), pla (plane 10), opp (plane 11), pla (plane 12), opp (plane 13)
  5. Pass moves set corresponding global features (0-4) instead of spatial planes
- **Reference**: Implements exact algorithm from `fillRowV7()` lines 2503-2562 in `nninputs.cpp`

#### Planes 14-17: Ladder Detection
- **Algorithm**:
  1. **Plane 14 (Current board ladders)**:
     - Call `board.iterLadders()` to iterate over all ladder positions
     - For each ladder position, set plane 14 to 1.0
  2. **Plane 15 (Previous board ladders)**:
     - Get board state from 1 turn ago: `board.getBoardAtTurn(max(0, board.turnNumber - 1))`
     - Iterate ladders on previous board, set plane 15 to 1.0
  3. **Plane 16 (Previous-previous board ladders)**:
     - Get board state from 2 turns ago: `board.getBoardAtTurn(max(0, board.turnNumber - 2))`
     - Iterate ladders on previous-previous board, set plane 16 to 1.0
  4. **Plane 17 (Ladder escape/capture moves)**:
     - For each ladder position on current board:
       - If stone is opponent's and has >1 liberty:
         - For each working move (escape/capture move), set plane 17 to 1.0
- **Purpose**: Provides ladder information across multiple board states to help the network understand ladder tactics
- **Note**: Uses `numTurnsOfHistoryIncluded = 2` for Chinese rules

#### Planes 18-19: Area Ownership
- **Algorithm**:
  1. Call `board.calculateArea()` to compute area ownership (Benson's algorithm)
  2. Iterate over all board positions
  3. For each position:
     - If area owner == `nextPlayer`: set plane 18 to 1.0
     - If area owner == opponent: set plane 19 to 1.0
     - If area is neutral/unowned: both planes remain 0.0
- **Purpose**: Indicates territory/area ownership for area scoring (Chinese rules)
- **Algorithm Reference**: Uses Benson's algorithm for area calculation

#### Planes 20-21: Encore Stones
- **Algorithm**: Zero-initialized (no explicit setting needed)
- **Purpose**: Second encore starting stones for Japanese rules
- **Chinese Rules**: Always 0.0 (no encore phase in Chinese rules)

---

## Global Features (19 Values)

| Index | Name | Description | Chinese Rules Value |
|-------|------|-------------|---------------------|
| 0 | Pass 1 ago | 1.0 if the most recent move was a pass | (depends on history) |
| 1 | Pass 2 ago | 1.0 if 2 moves ago was a pass | (depends on history) |
| 2 | Pass 3 ago | 1.0 if 3 moves ago was a pass | (depends on history) |
| 3 | Pass 4 ago | 1.0 if 4 moves ago was a pass | (depends on history) |
| 4 | Pass 5 ago | 1.0 if 5 moves ago was a pass | (depends on history) |
| 5 | Komi | `selfKomi / 20.0` (clipped to board area bounds) | komi/20.0 |
| 6 | Ko rule flag 1 | Positional/situational ko indicator | Configurable (see Rules configuration) |
| 7 | Ko rule flag 2 | Ko rule sub-type | Configurable (see Rules configuration) |
| 8 | Suicide legal | 1.0 if multi-stone suicide is allowed | 1.0 |
| 9 | Territory scoring | 1.0 if using territory scoring | 0.0 (area scoring) |
| 10 | Tax rule flag 1 | Seki/tax rule indicator | 0.0 |
| 11 | Tax rule flag 2 | Tax rule sub-type | 0.0 |
| 12 | Encore phase 1 | 1.0 if in encore phase 1+ | 0.0 |
| 13 | Encore phase 2 | 1.0 if in encore phase 2 | 0.0 |
| 14 | Pass ends phase | 1.0 if a pass would end the current phase | (depends on state) |
| 15 | Playout flag | 1.0 if playout doubling advantage is nonzero | 0.0 |
| 16 | Playout advantage | `0.5 * playoutDoublingAdvantage` | 0.0 |
| 17 | Button | 1.0 if button go variant | 0.0 |
| 18 | Komi parity wave | Triangular wave based on komi parity | (computed) |

### Notes on Global Features

- **Self Komi**: From the perspective of the current player. For Black, it's `komi`. For White, it's `-komi`.

- **Komi Clipping**: The komi value is clipped to `±(boardArea + 20)` before dividing by 20.

- **Chinese Rules Constants**: For Chinese rules with simple ko:
  - Features 6-7: **Configurable** via `Rules` struct (see Rules Configuration below)
    - Default (`.defaultRules`): `1.0, 0.5` (backward compatible with integration tests)
    - Proper (`.chineseRules`): `0.0, 0.0` (per documentation, verify against C++ reference)
  - Feature 8: `1.0` (multi-stone suicide allowed)
  - Feature 9: `0.0` (area scoring, not territory)
  - Features 10-11: `0.0` (no tax rule)
  - Features 12-13: `0.0` (no encore phase)
  - Features 15-16: `0.0` (no playout doubling)
  - Feature 17: `0.0` (no button go)

- **Rules Configuration**: Features 6-7 can be configured when creating `BoardState`:
  ```swift
  // Default (backward compatible): uses .defaultRules (1.0, 0.5)
  let boardState = BoardState(board: board)
  
  // Proper Chinese rules: uses .chineseRules (0.0, 0.0)
  let boardState = BoardState(board: board, rules: .chineseRules)
  ```
  The default configuration (`.defaultRules`) maintains backward compatibility with existing integration tests that were generated with values (1.0, 0.5).

- **Komi Parity Wave (Feature 18)**: A triangular wave that helps the neural network understand komi parity effects. The formula creates a wave with period 2 komi points, peaking around drawable komi values.

### Global Features Filling Algorithm

The algorithm fills global features in the following order, based on `fillRowV7()`:

#### Features 0-4: Pass History
- **Algorithm**: Set during spatial history filling (planes 9-13)
- **Process**: When processing move history in `fillPlanes9To13History()`:
  - If move 1 ago is a pass: set global[0] = 1.0
  - If move 2 ago is a pass: set global[1] = 1.0
  - If move 3 ago is a pass: set global[2] = 1.0
  - If move 4 ago is a pass: set global[3] = 1.0
  - If move 5 ago is a pass: set global[4] = 1.0
- **Note**: These features are set before `fillGlobalFeatures()` is called, so they are preserved during global feature initialization

#### Feature 5: Komi
- **Algorithm**:
  1. Calculate `selfKomi` (perspective-aware komi):
     - If `nextPlayer == .white`: `selfKomi = komi`
     - If `nextPlayer == .black`: `selfKomi = -komi`
  2. Clip `selfKomi` to bounds: `±(boardArea + 20)` where `boardArea = 19 × 19 = 361`
     - `maxKomi = 361 + 20 = 381`
     - If `selfKomi > 381`: set to 381
     - If `selfKomi < -381`: set to -381
  3. Set `global[5] = selfKomi / 20.0`
- **Purpose**: Provides komi from the current player's perspective, normalized by dividing by 20
- **Note**: The clipping ensures the feature stays within reasonable bounds for the neural network

#### Features 6-7: Ko Rule Flags
- **Algorithm**: Set from `Rules` configuration (default: `.defaultRules`)
- **Purpose**: Indicates ko rule type (positional/situational ko for Japanese rules)
- **Chinese Rules Configuration**:
  - **Default** (`.defaultRules`): `1.0, 0.5` - Backward compatible with integration tests
  - **Proper** (`.chineseRules`): `0.0, 0.0` - Per documentation (verify against C++ reference)
- **Note**: 
  - The default configuration uses `1.0, 0.5` to maintain backward compatibility with existing reference files
  - For positional/situational ko (Japanese rules), feature 6 would be 1.0 and feature 7 would be ±0.5
  - To use proper Chinese rules per documentation, explicitly pass `.chineseRules` to `BoardState` initializer

#### Feature 8: Suicide Legal
- **Algorithm**: Set `global[8] = 1.0`
- **Purpose**: Indicates whether multi-stone suicide is allowed
- **Chinese Rules**: Always 1.0 (multi-stone suicide is allowed)

#### Feature 9: Territory Scoring
- **Algorithm**: Set to 0.0 (already zero-initialized)
- **Purpose**: Indicates scoring method (1.0 = territory scoring, 0.0 = area scoring)
- **Chinese Rules**: Always 0.0 (area scoring)

#### Features 10-11: Tax Rule Flags
- **Algorithm**: Set to 0.0 (already zero-initialized)
- **Purpose**: Indicates seki/tax rule handling (for Japanese rules)
- **Chinese Rules**: Always 0.0 (no tax rule)

#### Features 12-13: Encore Phase
- **Algorithm**: Set to 0.0 (already zero-initialized)
- **Purpose**: Indicates encore phase status (for Japanese rules cleanup)
- **Chinese Rules**: Always 0.0 (no encore phase)

#### Feature 14: Pass Ends Phase
- **Algorithm**: See [Pass Ends Phase Algorithm](#pass-ends-phase-algorithm-global-feature-14) below for detailed description
- **Overview**:
  1. Calculate ko hash before the pass would be made
  2. Check if consecutive ending passes would be >= 2
  3. Check if pass would be a spight-style ending pass
  4. Set `global[14] = 1.0` if any condition is true, else `0.0`
- **Purpose**: Indicates whether a pass would end the current phase
- **Reference**: Implements KataGo's `passWouldEndPhase()` algorithm

#### Features 15-16: Playout Doubling Advantage
- **Algorithm**: Set to 0.0 (already zero-initialized)
- **Purpose**: Used for handicap playout doubling advantage
- **Chinese Rules**: Always 0.0 (not used)

#### Feature 17: Button Go Variant
- **Algorithm**: Set to 0.0 (already zero-initialized)
- **Purpose**: Indicates button go variant
- **Chinese Rules**: Always 0.0 (not used)

#### Feature 18: Komi Parity Wave
- **Algorithm**: See [Komi Parity Wave Algorithm](#komi-parity-wave-algorithm-global-feature-18) below for detailed description
- **Overview**:
  1. Determine if board area is even (19×19 = 361, so odd)
  2. Calculate `drawableKomisAreEven = boardAreaIsEven`
  3. Find `komiFloor` (nearest drawable komi below `selfKomi`)
  4. Calculate `delta = selfKomi - komiFloor`, clamped to [0.0, 2.0]
  5. Create triangular wave based on delta
- **Purpose**: Helps neural network understand komi parity effects through a periodic signal
- **Note**: Only computed for area scoring (Chinese rules) or encore phase >= 2

---

## Algorithm Details

### History Filling Algorithm (Planes 9-13)

The history filling algorithm implements a nested conditional structure from `fillRowV7()` (lines 2503-2562 in `nninputs.cpp`). This algorithm fills spatial planes 9-13 with move locations and global features 0-4 with pass indicators.

**Algorithm Steps**:

1. **Initialization**:
   - Get `moveHistory` and `moveHistoryLen = moveHistory.count`
   - Set `maxTurnsOfHistoryToInclude = 5` (for Chinese rules)
   - Calculate `amountOfHistoryToTryToUse = min(maxTurnsOfHistoryToInclude, moveHistoryLen)`
   - Determine `pla = nextPlayer` and `opp = opposite player`

2. **Nested Conditional Structure**:
   The algorithm uses nested conditionals to check each move in reverse chronological order, following the pattern: opp, pla, opp, pla, opp.

   - **Move 1 ago (opponent, plane 9)**:
     ```
     if amountOfHistoryToTryToUse >= 1 && moveHistoryLen >= 1 && 
        moveHistory[moveHistoryLen - 1].player == opp:
         if move is pass:
             global[0] = 1.0
         else:
             spatial[plane 9, move location] = 1.0
     ```

   - **Move 2 ago (player, plane 10)**:
     ```
     if (above condition true) && amountOfHistoryToTryToUse >= 2 && 
        moveHistoryLen >= 2 && moveHistory[moveHistoryLen - 2].player == pla:
         if move is pass:
             global[1] = 1.0
         else:
             spatial[plane 10, move location] = 1.0
     ```

   - **Move 3 ago (opponent, plane 11)**: Similar nested structure
   - **Move 4 ago (player, plane 12)**: Similar nested structure
   - **Move 5 ago (opponent, plane 13)**: Similar nested structure

3. **Key Properties**:
   - **Alternating Pattern**: The algorithm expects moves to alternate between opponent and player
   - **Nested Structure**: Each deeper level is only checked if the previous level's condition is true
   - **Pass Handling**: Pass moves set global features (0-4) instead of spatial planes
   - **Boundary Checks**: Each level checks both `amountOfHistoryToTryToUse` and `moveHistoryLen` to avoid index errors

4. **Chinese Rules Simplification**:
   - No game end or phase end logic needed
   - `maxTurnsOfHistoryToInclude` is always 5
   - No special handling for phase transitions

**Reference**: This algorithm exactly mirrors the C++ implementation in `fillRowV7()` at lines 2503-2562 of `nninputs.cpp`.

### Pass Ends Phase Algorithm (Global Feature 14)

The `passWouldEndPhase()` algorithm determines if a pass would end the current phase. This is important for Chinese rules with simple ko, where two consecutive passes can end the game.

**Algorithm Steps**:

1. **Calculate Ko Hash Before Pass**:
   - Hash the board state (all stone positions)
   - Hash the ko point (if exists)
   - Hash the player to move
   - This creates a unique identifier for the ko situation

2. **Check Consecutive Ending Passes**:
   - Count consecutive passes from the end of move history
   - Only count passes (non-pass moves reset the count)
   - Calculate `newConsecutiveEndingPasses = consecutiveEndingPasses + 1` (for the pass we're about to make)
   - For simple ko (Chinese rules): increment count
   - If `newConsecutiveEndingPasses >= 2`: return true

3. **Check Spight-Style Ending Pass**:
   - Extract ko hashes from all previous passes in move history
   - Reconstruct board state before each pass and calculate ko hash
   - For the current player (black or white), check if `koHashBeforeMove` matches any previous pass ko hash
   - If match found: return true (spight-style ending)

4. **Return Result**:
   - If either consecutive passes >= 2 OR spight-style ending: return true
   - Otherwise: return false
   - Set `global[14] = 1.0` if true, else `0.0`

**Key Functions**:
- `getKoHash(board, movePla)`: Calculates hash of board state, ko point, and player
- `newConsecutiveEndingPassesAfterPass(board, movePla)`: Calculates consecutive ending passes after a pass
- `getPassHistoryHashes(board, movePla)`: Extracts ko hashes from previous passes
- `wouldBeSpightlikeEndingPass(board, movePla, koHashBeforeMove)`: Checks if pass would be spight-style ending

**Chinese Rules**: For simple ko, `phaseHasSpightlikeEndingAndPassHistoryClearing()` returns true, so consecutive passes are always incremented.

**Reference**: Implements KataGo's `BoardHistory::passWouldEndPhase()` algorithm.

### Komi Parity Wave Algorithm (Global Feature 18)

The komi parity wave creates a triangular wave signal that helps the neural network understand komi parity effects. The wave has a period of 2 komi points and peaks around drawable komi values.

**Algorithm Steps**:

1. **Determine Board Area Parity**:
   - `boardArea = xSize × ySize = 19 × 19 = 361`
   - `boardAreaIsEven = (361 % 2 == 0) = false` (odd)

2. **Determine Drawable Komi Parity**:
   - `drawableKomisAreEven = boardAreaIsEven`
   - For 19×19: `drawableKomisAreEven = false` (drawable komis are odd integers)

3. **Calculate Komi Floor**:
   - Find the nearest drawable komi below `selfKomi`
   - If `drawableKomisAreEven`:
     - `komiFloor = floor(selfKomi / 2.0) × 2.0`
   - Else (odd, as in 19×19):
     - `komiFloor = floor((selfKomi - 1.0) / 2.0) × 2.0 + 1.0`
   - Example: If `selfKomi = 7.5`, then `komiFloor = floor((7.5 - 1.0) / 2.0) × 2.0 + 1.0 = floor(3.25) × 2.0 + 1.0 = 3 × 2.0 + 1.0 = 7.0`

4. **Calculate Delta**:
   - `delta = selfKomi - komiFloor`
   - Clamp `delta` to [0.0, 2.0]:
     - If `delta < 0.0`: set to `0.0`
     - If `delta > 2.0`: set to `2.0`

5. **Create Triangular Wave**:
   - If `delta < 0.5`:
     - `wave = delta` (rising edge: 0.0 → 0.5)
   - Else if `delta < 1.5`:
     - `wave = 1.0 - delta` (falling edge: 0.5 → -0.5)
   - Else:
     - `wave = delta - 2.0` (rising edge: -0.5 → 0.0)
   - Set `global[18] = wave`

**Wave Properties**:
- **Period**: 2.0 komi points
- **Peak**: At `delta = 0.5` (wave = 0.5)
- **Trough**: At `delta = 1.5` (wave = -0.5)
- **Zero Crossings**: At `delta = 0.0` and `delta = 2.0` (wave = 0.0)

**Purpose**: The triangular wave provides a periodic signal that helps the neural network understand how komi parity affects game outcomes. The wave peaks around drawable komi values, making it easier for the network to learn komi-related patterns.

**Example**: For `selfKomi = 7.5`:
- `komiFloor = 7.0`
- `delta = 0.5`
- `wave = 0.5` (at peak)

**Reference**: Implements the komi parity wave calculation from `fillRowV7()`.

---

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Spatial 0 (on board) | ✅ Implemented | Always 1.0 for all positions |
| Spatial 1-2 (stones) | ✅ Implemented | Own/opponent perspective based on nextPlayer |
| Spatial 3-5 (liberties) | ✅ Implemented | Liberty counting per stone |
| Spatial 6 (ko-ban) | ✅ Implemented | Uses Board.koPoint for simple ko |
| Spatial 7 (ko recapture blocked) | ✅ Implemented | 0.0 for Chinese rules (no encore) |
| Spatial 8 (reserved) | ✅ Implemented | Zero-initialized (0.0 for Chinese rules, no encore) |
| Spatial 9-13 (history) | ✅ Implemented | Uses Board.moveHistory, fills planes 9-13 with move locations, sets global 0-4 for passes |
| Spatial 14-17 (ladders) | ✅ Implemented | Uses Board.iterLadders() with ladder detection. Feature 14: current board ladders. Feature 15: previous board (1 turn ago). Feature 16: previous-previous board (2 turns ago). Feature 17: ladder escape/capture moves for opponent stones with >1 liberty. |
| Spatial 18-19 (area) | ✅ Implemented | Uses Board.calculateArea() (Benson's algorithm) |
| Spatial 20-21 (encore stones) | ✅ Implemented | Zero-initialized (0.0 for Chinese rules, no encore) |
| Global 0-4 (pass history) | ✅ Implemented | Set by fillPlanes9To13History() when pass moves are detected |
| Global 5 (komi) | ✅ Implemented | selfKomi/20.0, perspective-aware |
| Global 6-7 (ko rule) | ✅ Implemented | 0.0 for simple ko (Chinese rules) |
| Global 8 (suicide) | ✅ Implemented | 1.0 (multi-stone suicide allowed) |
| Global 9 (scoring) | ✅ Implemented | 0.0 (area scoring, Chinese rules) |
| Global 10-11 (tax) | ✅ Implemented | 0.0 (no tax rule, Chinese rules) |
| Global 12-13 (encore) | ✅ Implemented | 0.0 (no encore phase, Chinese rules) |
| Global 14 (pass ends phase) | ✅ Implemented | Implements KataGo's passWouldEndPhase() algorithm for Chinese rules (simple ko) |
| Global 15-17 (handicap/button) | ✅ Implemented | 0.0 (not used) |
| Global 18 (parity wave) | ✅ Implemented | Triangular wave calculation based on komi parity |

---

## References

- [KataGo nninputs.cpp](https://github.com/ChinChangYang/KataGo/blob/metal-coreml-stable/cpp/neuralnet/nninputs.cpp)
  - `fillRowV7()` function: Main function implementing the feature encoding algorithm
  - History filling algorithm: Lines 2503-2562 in `nninputs.cpp`
  - `passWouldEndPhase()` algorithm: Implements phase ending detection for Chinese rules (simple ko)
- KataGo Documentation: Neural Network Input Format
- Swift Implementation: `BoardState.swift` in this repository mirrors the `fillRowV7()` algorithm


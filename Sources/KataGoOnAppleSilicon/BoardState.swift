import CoreML
public struct BoardState {
	public let spatial: MLMultiArray
	public let global: MLMultiArray
	public init(spatial: MLMultiArray, global: MLMultiArray) {
		self.spatial = spatial
		self.global = global
	}
	public init(board: Board, nextPlayer: Stone = .black, komi: Float = 7.5, turnNumber _: Int = 0, rules: Rules = .defaultRules) {
		let spatialShape: [NSNumber] = [1, 22, 19, 19]
		self.spatial = try! MLMultiArray(shape: spatialShape, dataType: .float16)
		let globalShape: [NSNumber] = [1, 19]
		self.global = try! MLMultiArray(shape: globalShape, dataType: .float16)
		Self.fillSpatialFeatures(spatial: spatial, board: board, nextPlayer: nextPlayer, global: global)
		Self.fillGlobalFeatures(global: global, board: board, nextPlayer: nextPlayer, komi: komi, rules: rules)
	}
	private static func fillSpatialFeatures(spatial: MLMultiArray, board: Board, nextPlayer: Stone, global: MLMultiArray) {
		fillPlane0OnBoard(spatial: spatial)
		fillPlanes1And2Stones(spatial: spatial, board: board, nextPlayer: nextPlayer)
		fillPlanes3To5Liberties(spatial: spatial, board: board)
		fillPlane6KoBan(spatial: spatial, board: board)
		fillPlane7KoRecaptureBlocked(spatial: spatial)
		fillPlane8EncoreKoRecaptureBlocked(spatial: spatial)
		fillPlanes9To13History(spatial: spatial, global: global, board: board, nextPlayer: nextPlayer)
		fillPlanes14To17Ladders(spatial: spatial, board: board, nextPlayer: nextPlayer)
		fillPlanes18And19Area(spatial: spatial, board: board, nextPlayer: nextPlayer)
		fillPlanes20And21EncoreStones(spatial: spatial)
	}
	private static func fillPlane0OnBoard(spatial: MLMultiArray) {
		for y in 0..<19 {
			for x in 0..<19 {
				spatial[[0, 0, NSNumber(value: y), NSNumber(value: x)]] = 1.0
			}
		}
	}
	private static func fillPlanes1And2Stones(spatial: MLMultiArray, board: Board, nextPlayer: Stone) {
		for plane in 1...2 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
		let ownStone = nextPlayer
		let oppStone: Stone = (nextPlayer == .black) ? .white : .black
		for y in 0..<19 {
			for x in 0..<19 {
				let stone = board.stones[y][x]
				if stone == ownStone {
					spatial[[0, 1, NSNumber(value: y), NSNumber(value: x)]] = 1.0
				}
				else if stone == oppStone {
					spatial[[0, 2, NSNumber(value: y), NSNumber(value: x)]] = 1.0
				}
			}
		}
	}
	private static func fillPlanes3To5Liberties(spatial: MLMultiArray, board: Board) {
		for plane in 3...5 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
		for y in 0..<19 {
			for x in 0..<19 {
				let stone = board.stones[y][x]
				if stone != .empty {
					let libertyCount = board.liberties(of: Point(x: x, y: y))
					if libertyCount == 1 {
						spatial[[0, 3, NSNumber(value: y), NSNumber(value: x)]] = 1.0
					}
					else if libertyCount == 2 {
						spatial[[0, 4, NSNumber(value: y), NSNumber(value: x)]] = 1.0
					}
					else if libertyCount == 3 {
						spatial[[0, 5, NSNumber(value: y), NSNumber(value: x)]] = 1.0
					}
				}
			}
		}
	}
	private static func fillPlane6KoBan(spatial: MLMultiArray, board: Board) {
		for y in 0..<19 {
			for x in 0..<19 {
				spatial[[0, 6, NSNumber(value: y), NSNumber(value: x)]] = 0.0
			}
		}
		if let ko = board.koPoint {
			spatial[[0, 6, NSNumber(value: ko.y), NSNumber(value: ko.x)]] = 1.0
		}
	}
	private static func fillPlane7KoRecaptureBlocked(spatial: MLMultiArray) {
		for y in 0..<19 {
			for x in 0..<19 {
				spatial[[0, 7, NSNumber(value: y), NSNumber(value: x)]] = 0.0
			}
		}
	}
	private static func fillPlane8EncoreKoRecaptureBlocked(spatial: MLMultiArray) {
		for y in 0..<19 {
			for x in 0..<19 {
				spatial[[0, 8, NSNumber(value: y), NSNumber(value: x)]] = 0.0
			}
		}
	}
	private static func fillPlanes9To13History(spatial: MLMultiArray, global: MLMultiArray, board: Board, nextPlayer: Stone) {
		for plane in 9...13 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
		for i in 0..<5 {
			global[i] = 0.0
		}
		let moveHistory = board.moveHistory
		let moveHistoryLen = moveHistory.count
		let maxTurnsOfHistoryToInclude = 5
		let amountOfHistoryToTryToUse = min(maxTurnsOfHistoryToInclude, moveHistoryLen)
		let pla = nextPlayer
		let opp: Stone = (nextPlayer == .black) ? .white : .black
		if amountOfHistoryToTryToUse >= 1 && moveHistoryLen >= 1 && moveHistory[moveHistoryLen - 1].player == opp {
			let prev1Move = moveHistory[moveHistoryLen - 1]
			if prev1Move.isPass {
				global[0] = 1.0
			} else if let prev1Loc = prev1Move.location {
				spatial[[0, 9, NSNumber(value: prev1Loc.y), NSNumber(value: prev1Loc.x)]] = 1.0
			}
			if amountOfHistoryToTryToUse >= 2 && moveHistoryLen >= 2 && moveHistory[moveHistoryLen - 2].player == pla {
				let prev2Move = moveHistory[moveHistoryLen - 2]
				if prev2Move.isPass {
					global[1] = 1.0
				} else if let prev2Loc = prev2Move.location {
					spatial[[0, 10, NSNumber(value: prev2Loc.y), NSNumber(value: prev2Loc.x)]] = 1.0
				}
				if amountOfHistoryToTryToUse >= 3 && moveHistoryLen >= 3 && moveHistory[moveHistoryLen - 3].player == opp {
					let prev3Move = moveHistory[moveHistoryLen - 3]
					if prev3Move.isPass {
						global[2] = 1.0
					} else if let prev3Loc = prev3Move.location {
						spatial[[0, 11, NSNumber(value: prev3Loc.y), NSNumber(value: prev3Loc.x)]] = 1.0
					}
					if amountOfHistoryToTryToUse >= 4 && moveHistoryLen >= 4 && moveHistory[moveHistoryLen - 4].player == pla {
						let prev4Move = moveHistory[moveHistoryLen - 4]
						if prev4Move.isPass {
							global[3] = 1.0
						} else if let prev4Loc = prev4Move.location {
							spatial[[0, 12, NSNumber(value: prev4Loc.y), NSNumber(value: prev4Loc.x)]] = 1.0
						}
						if amountOfHistoryToTryToUse >= 5 && moveHistoryLen >= 5 && moveHistory[moveHistoryLen - 5].player == opp {
							let prev5Move = moveHistory[moveHistoryLen - 5]
							if prev5Move.isPass {
								global[4] = 1.0
							} else if let prev5Loc = prev5Move.location {
								spatial[[0, 13, NSNumber(value: prev5Loc.y), NSNumber(value: prev5Loc.x)]] = 1.0
							}
						}
					}
				}
			}
		}
	}
	private static func fillPlanes14To17Ladders(spatial: MLMultiArray, board: Board, nextPlayer: Stone) {
		for plane in 14...17 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
		let opp: Stone = (nextPlayer == .black) ? .white : .black
		board.iterLadders { loc, workingMoves in
			let y = loc.y
			let x = loc.x
			spatial[[0, 14, NSNumber(value: y), NSNumber(value: x)]] = 1.0
			let stone = board.stones[y][x]
			if stone == opp && board.liberties(of: loc) > 1 {
				for workingMove in workingMoves {
					spatial[[0, 17, NSNumber(value: workingMove.y), NSNumber(value: workingMove.x)]] = 1.0
				}
			}
		}
		let prevBoard = board.getBoardAtTurn(max(0, board.turnNumber - 1))
		prevBoard.iterLadders { loc, _ in
			let y = loc.y
			let x = loc.x
			spatial[[0, 15, NSNumber(value: y), NSNumber(value: x)]] = 1.0
		}
		let prevPrevBoard = board.getBoardAtTurn(max(0, board.turnNumber - 2))
		prevPrevBoard.iterLadders { loc, _ in
			let y = loc.y
			let x = loc.x
			spatial[[0, 16, NSNumber(value: y), NSNumber(value: x)]] = 1.0
		}
	}
	private static func fillPlanes18And19Area(spatial: MLMultiArray, board: Board, nextPlayer: Stone) {
		for plane in 18...19 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
		let area = board.calculateArea()
		let oppStone: Stone = (nextPlayer == .black) ? .white : .black
		for y in 0..<19 {
			for x in 0..<19 {
				if let owner = area[y][x] {
					if owner == nextPlayer {
						spatial[[0, 18, NSNumber(value: y), NSNumber(value: x)]] = 1.0
					}
					else if owner == oppStone {
						spatial[[0, 19, NSNumber(value: y), NSNumber(value: x)]] = 1.0
					}
				}
			}
		}
	}
	private static func fillPlanes20And21EncoreStones(spatial: MLMultiArray) {
		for plane in 20...21 {
			for y in 0..<19 {
				for x in 0..<19 {
					spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]] = 0.0
				}
			}
		}
	}
	private static func getKoHash(board: Board, movePla: Stone) -> UInt64 {
		var hash: UInt64 = 0
		for y in 0..<19 {
			for x in 0..<19 {
				let stone = board.stones[y][x]
				let stoneValue = stone.rawValue
				hash = hash &* 31 &+ UInt64(y * 19 + x) &* 7 &+ UInt64(stoneValue)
			}
		}
		if let ko = board.koPoint {
			hash = hash &* 31 &+ UInt64(ko.y * 19 + ko.x) &* 17
		}
		hash = hash &* 31 &+ UInt64(movePla.rawValue) &* 19
		return hash
	}
	private static func phaseHasSpightlikeEndingAndPassHistoryClearing() -> Bool {
		true
	}
	private static func newConsecutiveEndingPassesAfterPass(board: Board, movePla _: Stone) -> Int {
		var consecutiveEndingPasses = 0
		let moveHistory = board.moveHistory
		var i = moveHistory.count - 1
		while i >= 0 {
			if moveHistory[i].isPass {
				consecutiveEndingPasses += 1
				i -= 1
			} else {
				break
			}
		}
		var newConsecutiveEndingPasses = consecutiveEndingPasses
		if phaseHasSpightlikeEndingAndPassHistoryClearing() {
			newConsecutiveEndingPasses += 1
		} else {
			newConsecutiveEndingPasses = 0
		}
		return newConsecutiveEndingPasses
	}
	private static func getPassHistoryHashes(board: Board, movePla _: Stone) -> (blackHashes: [UInt64], whiteHashes: [UInt64]) {
		var blackHashes: [UInt64] = []
		var whiteHashes: [UInt64] = []
		let moveHistory = board.moveHistory
		let reconstructedBoard = Board()
		var currentBoard = reconstructedBoard
		for move in moveHistory {
			if move.isPass {
				let koHash = getKoHash(board: currentBoard, movePla: move.player)
				if move.player == .black {
					blackHashes.append(koHash)
				} else {
					whiteHashes.append(koHash)
				}
			} else if let loc = move.location {
				let newBoard = currentBoard.copy()
				_ = newBoard.playMove(at: loc, stone: move.player)
				currentBoard = newBoard
			}
		}
		return (blackHashes, whiteHashes)
	}
	private static func wouldBeSpightlikeEndingPass(board: Board, movePla: Stone, koHashBeforeMove: UInt64) -> Bool {
		if !phaseHasSpightlikeEndingAndPassHistoryClearing() {
			return false
		}
		let (blackHashes, whiteHashes) = getPassHistoryHashes(board: board, movePla: movePla)
		if movePla == .black {
			return blackHashes.contains(koHashBeforeMove)
		}
		return whiteHashes.contains(koHashBeforeMove)
	}
	private static func passWouldEndPhase(board: Board, movePla: Stone) -> Bool {
		let koHashBeforeMove = getKoHash(board: board, movePla: movePla)
		if newConsecutiveEndingPassesAfterPass(board: board, movePla: movePla) >= 2 {
			return true
		}
		if wouldBeSpightlikeEndingPass(board: board, movePla: movePla, koHashBeforeMove: koHashBeforeMove) {
			return true
		}
		return false
	}
	private static func fillGlobalFeatures(global: MLMultiArray, board: Board, nextPlayer: Stone, komi: Float, rules: Rules) {
		for i in 5..<19 {
			global[i] = 0.0
		}
		let selfKomi = calculateSelfKomi(nextPlayer: nextPlayer, komi: komi)
		fillGlobalFeature5Komi(global: global, selfKomi: selfKomi)
		fillGlobalFeatures6To13ChineseRules(global: global, rules: rules)
		fillGlobalFeature14PassEndsPhase(global: global, board: board, nextPlayer: nextPlayer)
		fillGlobalFeatures15To17Unused(global: global)
		fillGlobalFeature18KomiParityWave(global: global, selfKomi: selfKomi)
	}
	private static func calculateSelfKomi(nextPlayer: Stone, komi: Float) -> Float {
		let boardArea: Float = 19.0 * 19.0
		let komiClipRadius: Float = 20.0
		var selfKomi = (nextPlayer == .white) ? komi : -komi
		let maxKomi = boardArea + komiClipRadius
		if selfKomi > maxKomi { selfKomi = maxKomi }
		if selfKomi < -maxKomi { selfKomi = -maxKomi }
		return selfKomi
	}
	private static func fillGlobalFeature5Komi(global: MLMultiArray, selfKomi: Float) {
		global[5] = NSNumber(value: selfKomi / 20.0)
	}
	private static func fillGlobalFeatures6To13ChineseRules(global: MLMultiArray, rules: Rules) {
		global[6] = NSNumber(value: rules.koRuleFlag1)
		global[7] = NSNumber(value: rules.koRuleFlag2)
		global[8] = 1.0
	}
	private static func fillGlobalFeature14PassEndsPhase(global: MLMultiArray, board: Board, nextPlayer: Stone) {
		let passEndsPhase = passWouldEndPhase(board: board, movePla: nextPlayer)
		global[14] = passEndsPhase ? 1.0 : 0.0
	}
	private static func fillGlobalFeatures15To17Unused(global _: MLMultiArray) {
	}
	private static func fillGlobalFeature18KomiParityWave(global: MLMultiArray, selfKomi: Float) {
		let xSize = 19
		let ySize = 19
		let boardAreaIsEven = (xSize * ySize) % 2 == 0
		let drawableKomisAreEven = boardAreaIsEven
		let komiFloor: Float
		if drawableKomisAreEven {
			komiFloor = floor(selfKomi / 2.0) * 2.0
		} else {
			komiFloor = floor((selfKomi - 1.0) / 2.0) * 2.0 + 1.0
		}
		var delta = selfKomi - komiFloor
		if delta < 0.0 {
			delta = 0.0
		}
		if delta > 2.0 {
			delta = 2.0
		}
		let wave: Float
		if delta < 0.5 {
			wave = delta
		} else if delta < 1.5 {
			wave = 1.0 - delta
		} else {
			wave = delta - 2.0
		}
		global[18] = NSNumber(value: wave)
	}
}
public struct ModelOutput {
	public let policy: MLMultiArray
	public let ownership: MLMultiArray
	public let valueArray: MLMultiArray
	public let miscValueArray: MLMultiArray?
	public let moreMiscValueArray: MLMultiArray?
	public init(
		policy: MLMultiArray,
		ownership: MLMultiArray,
		valueArray: MLMultiArray,
		miscValueArray: MLMultiArray? = nil,
		moreMiscValueArray: MLMultiArray? = nil
	) {
		self.policy = policy
		self.ownership = ownership
		self.valueArray = valueArray
		self.miscValueArray = miscValueArray
		self.moreMiscValueArray = moreMiscValueArray
	}
	private static let valueArraySize = 3
	private static let miscValueArraySize = 10
	private static let moreMiscValueArraySize = 8
	private func getValueArrayValue(at index: Int) -> Float {
		let value = valueArray[[0, NSNumber(value: index)]].doubleValue
		return value.isNaN ? valueArray[[0, NSNumber(value: index)]].floatValue : Float(value)
	}
	private func getOptionalArrayValue(_ array: MLMultiArray?, at index: Int) -> Float? {
		guard let array else { return nil }
		return array[[0, NSNumber(value: index)]].floatValue
	}
	public var whiteWin: Float {
		getValueArrayValue(at: 0)
	}
	public var whiteLoss: Float {
		getValueArrayValue(at: 1)
	}
	public var noResult: Float {
		getValueArrayValue(at: 2)
	}
	public var whiteScoreMean: Float? {
		getOptionalArrayValue(miscValueArray, at: 0)
	}
	public var whiteScoreMeanSq: Float? {
		getOptionalArrayValue(miscValueArray, at: 1)
	}
	public var whiteLead: Float? {
		getOptionalArrayValue(miscValueArray, at: 2)
	}
	public var varTimeLeft: Float? {
		getOptionalArrayValue(miscValueArray, at: 3)
	}
	public var shorttermWinlossError: Float? {
		getOptionalArrayValue(moreMiscValueArray, at: 0)
	}
	public var shorttermScoreError: Float? {
		getOptionalArrayValue(moreMiscValueArray, at: 1)
	}
	private func extractRawPolicy() -> [Float] {
		var rawPolicy = Array(repeating: Float(0.0), count: 362)
		let shape = policy.shape.map(\.intValue)
		let dimCount = shape.count
		for y in 0..<19 {
			for x in 0..<19 {
				let positionIndex = y * 19 + x
				let value: Float
				if dimCount == 3 && shape[1] == 6 && shape[2] == 362 {
					value = policy[[0, 0, NSNumber(value: positionIndex)]].floatValue
				} else if dimCount == 4 {
					if shape[1] == 19 {
						value = policy[[0, NSNumber(value: y), NSNumber(value: x), 0]].floatValue
					} else {
						value = policy[[0, 0, NSNumber(value: y), NSNumber(value: x)]].floatValue
					}
				} else if dimCount == 3 && shape[1] == 19 {
					value = policy[[0, NSNumber(value: y), NSNumber(value: x)]].floatValue
				} else {
					if positionIndex < policy.count {
						value = policy[positionIndex].floatValue
					} else {
						value = 0.0
					}
				}
				rawPolicy[positionIndex] = value
			}
		}
		if dimCount == 3 && shape[1] == 6 && shape[2] == 362 {
			rawPolicy[361] = policy[[0, 0, NSNumber(value: 361)]].floatValue
		} else if policy.count > 361 {
			rawPolicy[361] = policy[361].floatValue
		}
		return rawPolicy
	}
	private func extractRawOwnership() -> [Float] {
		var rawOwnership = Array(repeating: Float(0.0), count: 19 * 19)
		let shape = ownership.shape.map(\.intValue)
		let is4D = shape.count == 4
		for y in 0..<19 {
			for x in 0..<19 {
				let positionIndex = y * 19 + x
				let value: Float
				if is4D {
					value = ownership[[0, 0, NSNumber(value: y), NSNumber(value: x)]].floatValue
				} else {
					value = ownership[[0, NSNumber(value: y), NSNumber(value: x)]].floatValue
				}
				rawOwnership[positionIndex] = value
			}
		}
		return rawOwnership
	}
	public func postprocess(
		board: Board,
		nextPlayer: Stone,
		modelVersion: Int = 15,
		postProcessParams: PostProcessParams = .default
	) -> PostProcessedModelOutput {
		let rawWhiteWinProb = Double(whiteWin)
		let rawWhiteLossProb = Double(whiteLoss)
		let rawWhiteNoResultProb = Double(noResult)
		let rawWhiteScoreMean = Double(whiteScoreMean ?? 0.0)
		let rawWhiteScoreMeanSq = Double(whiteScoreMeanSq ?? 0.0)
		let rawWhiteLead = Double(whiteLead ?? 0.0)
		let rawVarTimeLeft = Double(varTimeLeft ?? 0.0)
		let rawShorttermWinlossError = Double(shorttermWinlossError ?? 0.0)
		let rawShorttermScoreError = Double(shorttermScoreError ?? 0.0)
		let valueResults = postprocessValueOutputs(
			rawWhiteWinProb: rawWhiteWinProb,
			rawWhiteLossProb: rawWhiteLossProb,
			rawWhiteNoResultProb: rawWhiteNoResultProb,
			rawWhiteScoreMean: rawWhiteScoreMean,
			rawWhiteScoreMeanSq: rawWhiteScoreMeanSq,
			rawWhiteLead: rawWhiteLead,
			rawVarTimeLeft: rawVarTimeLeft,
			rawShorttermWinlossError: rawShorttermWinlossError,
			rawShorttermScoreError: rawShorttermScoreError,
			nextPlayer: nextPlayer,
			modelVersion: modelVersion,
			postProcessParams: postProcessParams
		)
		let rawPolicy = extractRawPolicy()
		let policyProbs = postprocessPolicy(
			rawPolicy: rawPolicy,
			board: board,
			nextPlayer: nextPlayer,
			postProcessParams: postProcessParams
		)
		let rawOwnership = extractRawOwnership()
		let ownershipValues = postprocessOwnership(
			rawOwnership: rawOwnership,
			board: board,
			nextPlayer: nextPlayer,
			postProcessParams: postProcessParams
		)
		return PostProcessedModelOutput(
			whiteWinProb: valueResults.whiteWinProb,
			whiteLossProb: valueResults.whiteLossProb,
			whiteNoResultProb: valueResults.whiteNoResultProb,
			whiteScoreMean: valueResults.whiteScoreMean,
			whiteScoreMeanSq: valueResults.whiteScoreMeanSq,
			whiteLead: valueResults.whiteLead,
			varTimeLeft: valueResults.varTimeLeft,
			shorttermWinlossError: valueResults.shorttermWinlossError,
			shorttermScoreError: valueResults.shorttermScoreError,
			policyProbs: policyProbs,
			ownership: ownershipValues
		)
	}
}

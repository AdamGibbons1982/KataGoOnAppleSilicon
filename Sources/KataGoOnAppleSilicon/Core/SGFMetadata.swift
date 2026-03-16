import Foundation
public struct SGFMetadata {
	public var initialized: Bool = false
	public var inverseBRank: Int = 0
	public var inverseWRank: Int = 0
	public var bIsUnranked: Bool = false
	public var wIsUnranked: Bool = false
	public var bRankIsUnknown: Bool = false
	public var wRankIsUnknown: Bool = false
	public var bIsHuman: Bool = false
	public var wIsHuman: Bool = false
	public var gameIsUnrated: Bool = false
	public var gameRatednessIsUnknown: Bool = false
	public var tcIsUnknown: Bool = false
	public var tcIsNone: Bool = false
	public var tcIsAbsolute: Bool = false
	public var tcIsSimple: Bool = false
	public var tcIsByoYomi: Bool = false
	public var tcIsCanadian: Bool = false
	public var tcIsFischer: Bool = false
	public var mainTimeSeconds: Double = 0.0
	public var periodTimeSeconds: Double = 0.0
	public var byoYomiPeriods: Int = 0
	public var canadianMoves: Int = 0
	public var gameDate: Date
	public var source: Int = 0
	public static let SOURCE_OGS = 1
	public static let SOURCE_KGS = 2
	public static let SOURCE_FOX = 3
	public static let SOURCE_TYGEM = 4
	public static let SOURCE_GOGOD = 5
	public static let SOURCE_GO4GO = 6
	public static let METADATA_INPUT_NUM_CHANNELS = 192
	public init() {
		self.gameDate = Date(timeIntervalSince1970: 0)
	}
	public static func getProfile(_ humanSLProfileName: String) -> Self {
		if humanSLProfileName.isEmpty || humanSLProfileName == "_" || humanSLProfileName == "\"\"" {
			return Self()
		}
		var ranksStr: String
		var preAZ: Bool
		if humanSLProfileName.hasPrefix("rank_") {
			ranksStr = String(humanSLProfileName.dropFirst(5))
			preAZ = false
		} else if humanSLProfileName.hasPrefix("preaz_") {
			ranksStr = String(humanSLProfileName.dropFirst(6))
			preAZ = true
		} else {
			return Self()
		}
		func getInverseRank(_ rankStr: String) -> Int? {
			switch rankStr {
			case "9d": return 1
			case "8d": return 2
			case "7d": return 3
			case "6d": return 4
			case "5d": return 5
			case "4d": return 6
			case "3d": return 7
			case "2d": return 8
			case "1d": return 9
			case "1k": return 10
			case "2k": return 11
			case "3k": return 12
			case "4k": return 13
			case "5k": return 14
			case "6k": return 15
			case "7k": return 16
			case "8k": return 17
			case "9k": return 18
			case "10k": return 19
			case "11k": return 20
			case "12k": return 21
			case "13k": return 22
			case "14k": return 23
			case "15k": return 24
			case "16k": return 25
			case "17k": return 26
			case "18k": return 27
			case "19k": return 28
			case "20k": return 29
			default: return nil
			}
		}
		if let inverseRank = getInverseRank(ranksStr) {
			return makeBasicRankProfile(inverseRankBlack: inverseRank, inverseRankWhite: inverseRank, preAZ: preAZ)
		}
		let pieces = ranksStr.split(separator: "_")
		if pieces.count == 2 {
			let blackRankStr = String(pieces[0])
			let whiteRankStr = String(pieces[1])
			if let inverseRankBlack = getInverseRank(blackRankStr),
			   let inverseRankWhite = getInverseRank(whiteRankStr) {
				return makeBasicRankProfile(inverseRankBlack: inverseRankBlack, inverseRankWhite: inverseRankWhite, preAZ: preAZ)
			}
		}
		return Self()
	}
	private static func makeBasicRankProfile(inverseRankBlack: Int, inverseRankWhite: Int, preAZ: Bool) -> Self {
		var ret = Self()
		ret.initialized = true
		ret.inverseBRank = inverseRankBlack
		ret.inverseWRank = inverseRankWhite
		ret.bIsHuman = true
		ret.wIsHuman = true
		ret.gameRatednessIsUnknown = true
		ret.tcIsByoYomi = true
		ret.mainTimeSeconds = 1_200.0
		ret.periodTimeSeconds = 30.0
		ret.byoYomiPeriods = 5
		if preAZ {
			var components = DateComponents()
			components.year = 2_016
			components.month = 9
			components.day = 1
			ret.gameDate = Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
		} else {
			var components = DateComponents()
			components.year = 2_020
			components.month = 3
			components.day = 1
			ret.gameDate = Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
		}
		ret.source = SOURCE_KGS
		return ret
	}
	public static func fillMetadataRow(_ sgfMeta: Self, nextPlayer: Stone, boardArea: Int) -> [Float] {
		guard sgfMeta.initialized else {
			return Array(repeating: 0.0, count: METADATA_INPUT_NUM_CHANNELS)
		}
		var rowMetadata = Array(repeating: 0.0 as Float, count: METADATA_INPUT_NUM_CHANNELS)
		let plaIsHuman = (nextPlayer == .white) ? sgfMeta.wIsHuman : sgfMeta.bIsHuman
		let oppIsHuman = (nextPlayer == .white) ? sgfMeta.bIsHuman : sgfMeta.wIsHuman
		rowMetadata[0] = plaIsHuman ? 1.0 : 0.0
		rowMetadata[1] = oppIsHuman ? 1.0 : 0.0
		let plaIsUnranked = (nextPlayer == .white) ? sgfMeta.wIsUnranked : sgfMeta.bIsUnranked
		let oppIsUnranked = (nextPlayer == .white) ? sgfMeta.bIsUnranked : sgfMeta.wIsUnranked
		rowMetadata[2] = plaIsUnranked ? 1.0 : 0.0
		rowMetadata[3] = oppIsUnranked ? 1.0 : 0.0
		let plaRankIsUnknown = (nextPlayer == .white) ? sgfMeta.wRankIsUnknown : sgfMeta.bRankIsUnknown
		let oppRankIsUnknown = (nextPlayer == .white) ? sgfMeta.bRankIsUnknown : sgfMeta.wRankIsUnknown
		rowMetadata[4] = plaRankIsUnknown ? 1.0 : 0.0
		rowMetadata[5] = oppRankIsUnknown ? 1.0 : 0.0
		let RANK_START_IDX = 6
		let RANK_LEN_PER_PLA = 34
		let invPlaRank = (nextPlayer == .white) ? sgfMeta.inverseWRank : sgfMeta.inverseBRank
		let invOppRank = (nextPlayer == .white) ? sgfMeta.inverseBRank : sgfMeta.inverseWRank
		if !plaIsUnranked {
			let rankCount = min(invPlaRank, RANK_LEN_PER_PLA)
			for i in 0..<rankCount {
				rowMetadata[RANK_START_IDX + i] = 1.0
			}
		}
		if !oppIsUnranked {
			let rankCount = min(invOppRank, RANK_LEN_PER_PLA)
			for i in 0..<rankCount {
				rowMetadata[RANK_START_IDX + RANK_LEN_PER_PLA + i] = 1.0
			}
		}
		rowMetadata[74] = sgfMeta.gameRatednessIsUnknown ? 0.5 : (sgfMeta.gameIsUnrated ? 1.0 : 0.0)
		rowMetadata[75] = sgfMeta.tcIsUnknown ? 1.0 : 0.0
		rowMetadata[76] = sgfMeta.tcIsNone ? 1.0 : 0.0
		rowMetadata[77] = sgfMeta.tcIsAbsolute ? 1.0 : 0.0
		rowMetadata[78] = sgfMeta.tcIsSimple ? 1.0 : 0.0
		rowMetadata[79] = sgfMeta.tcIsByoYomi ? 1.0 : 0.0
		rowMetadata[80] = sgfMeta.tcIsCanadian ? 1.0 : 0.0
		rowMetadata[81] = sgfMeta.tcIsFischer ? 1.0 : 0.0
		let mainTimeSecondsCapped = min(max(sgfMeta.mainTimeSeconds, 0.0), 3.0 * 86_400.0)
		rowMetadata[82] = Float(0.4 * (log(mainTimeSecondsCapped + 60.0) - 6.5))
		let periodTimeSecondsCapped = min(max(sgfMeta.periodTimeSeconds, 0.0), 1.0 * 86_400.0)
		rowMetadata[83] = Float(0.3 * (log(periodTimeSecondsCapped + 1.0) - 3.0))
		let byoYomiPeriodsCapped = min(max(sgfMeta.byoYomiPeriods, 0), 50)
		rowMetadata[84] = Float(0.5 * (log(Double(byoYomiPeriodsCapped + 2)) - 1.5))
		let canadianMovesCapped = min(max(sgfMeta.canadianMoves, 0), 50)
		rowMetadata[85] = Float(0.25 * (log(Double(canadianMovesCapped + 2)) - 1.5))
		rowMetadata[86] = Float(0.5 * log(Double(boardArea) / 361.0))
		let DATE_START_IDX = 87
		let DATE_LEN = 32
		let calendar = Calendar(identifier: .gregorian)
		let date1970 = calendar.date(from: DateComponents(year: 1_970, month: 1, day: 1))!
		let startOfDay1970 = calendar.startOfDay(for: date1970)
		let startOfDayGame = calendar.startOfDay(for: sgfMeta.gameDate)
		let daysSince1970 = calendar.dateComponents([.day], from: startOfDay1970, to: startOfDayGame).day ?? 0
		var period = 7.0
		let factor = pow(80_000.0, 1.0 / Double(DATE_LEN - 1))
		let twopi = 2.0 * Double.pi
		for i in 0..<DATE_LEN {
			let numRevolutions = Double(daysSince1970) / period
			rowMetadata[DATE_START_IDX + i * 2 + 0] = Float(cos(numRevolutions * twopi))
			rowMetadata[DATE_START_IDX + i * 2 + 1] = Float(sin(numRevolutions * twopi))
			period *= factor
		}
		assert(sgfMeta.source >= 0 && sgfMeta.source < 16)
		rowMetadata[151 + sgfMeta.source] = 1.0
		return rowMetadata
	}
}

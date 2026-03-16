public struct Rules: Sendable {
	public enum KoRule: Sendable {
		case simple
		case positional
		case situational
	}
	public enum ScoringRule: Sendable {
		case area
		case territory
	}
	public let koRuleFlag1: Float
	public let koRuleFlag2: Float
	public let koRule: KoRule
	public let scoringRule: ScoringRule
	public init(koRuleFlag1: Float, koRuleFlag2: Float, koRule: KoRule, scoringRule: ScoringRule) {
		self.koRuleFlag1 = koRuleFlag1
		self.koRuleFlag2 = koRuleFlag2
		self.koRule = koRule
		self.scoringRule = scoringRule
	}
	public static let defaultRules = Self(
		koRuleFlag1: 1.0,
		koRuleFlag2: 0.5,
		koRule: .simple,
		scoringRule: .area
	)
	public static let chineseRules = Self(
		koRuleFlag1: 0.0,
		koRuleFlag2: 0.0,
		koRule: .simple,
		scoringRule: .area
	)
}

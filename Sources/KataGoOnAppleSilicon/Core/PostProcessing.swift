import Foundation
public struct PostProcessParams: Sendable {
    public let outputScaleMultiplier: Float
    public let scoreMeanMultiplier: Double
    public let scoreStdevMultiplier: Double
    public let leadMultiplier: Double
    public let varianceTimeMultiplier: Double
    public let shorttermValueErrorMultiplier: Double
    public let shorttermScoreErrorMultiplier: Double

    /// Default parameters matching the bundled KataGo AI model
    /// (`KataGoModel19x19fp16-adam-s11165M`, model version 15).
    /// Key non-obvious values:
    /// - `outputScaleMultiplier`: 1.0 (model description field; earlier code incorrectly used 8.0)
    /// - `shorttermScoreErrorMultiplier`: 150.0 (model description field; earlier code incorrectly used 30.0)
    public static let `default` = PostProcessParams(
        outputScaleMultiplier: 1.0,
        scoreMeanMultiplier: 20.0,
        scoreStdevMultiplier: 20.0,
        leadMultiplier: 20.0,
        varianceTimeMultiplier: 40.0,
        shorttermValueErrorMultiplier: 0.25,
        shorttermScoreErrorMultiplier: 150.0
    )

    public init(
        outputScaleMultiplier: Float,
        scoreMeanMultiplier: Double,
        scoreStdevMultiplier: Double,
        leadMultiplier: Double,
        varianceTimeMultiplier: Double,
        shorttermValueErrorMultiplier: Double,
        shorttermScoreErrorMultiplier: Double
    ) {
        self.outputScaleMultiplier = outputScaleMultiplier
        self.scoreMeanMultiplier = scoreMeanMultiplier
        self.scoreStdevMultiplier = scoreStdevMultiplier
        self.leadMultiplier = leadMultiplier
        self.varianceTimeMultiplier = varianceTimeMultiplier
        self.shorttermValueErrorMultiplier = shorttermValueErrorMultiplier
        self.shorttermScoreErrorMultiplier = shorttermScoreErrorMultiplier
    }
}
public func softPlus(_ x: Double) -> Double {
	if x > 40.0 {
		return x
	}
	return log(1.0 + exp(x))
}
public struct PostProcessedModelOutput {
	public let whiteWinProb: Double
	public let whiteLossProb: Double
	public let whiteNoResultProb: Double
	public let whiteScoreMean: Double
	public let whiteScoreMeanSq: Double
	public let whiteLead: Double
	public let varTimeLeft: Double
	public let shorttermWinlossError: Double
	public let shorttermScoreError: Double
	public let policyProbs: [Float]
	public let ownership: [Float]
}
public func postprocessValueOutputs(
	rawWhiteWinProb: Double,
	rawWhiteLossProb: Double,
	rawWhiteNoResultProb: Double,
	rawWhiteScoreMean: Double,
	rawWhiteScoreMeanSq: Double,
	rawWhiteLead: Double,
	rawVarTimeLeft: Double,
	rawShorttermWinlossError: Double,
	rawShorttermScoreError: Double,
	nextPlayer: Stone,
	modelVersion _: Int,
	postProcessParams: PostProcessParams,
	koRule: Rules.KoRule = .simple,
	scoringRule: Rules.ScoringRule = .area
) -> (
	whiteWinProb: Double,
	whiteLossProb: Double,
	whiteNoResultProb: Double,
	whiteScoreMean: Double,
	whiteScoreMeanSq: Double,
	whiteLead: Double,
	varTimeLeft: Double,
	shorttermWinlossError: Double,
	shorttermScoreError: Double
) {
	let winLogits = rawWhiteWinProb * Double(postProcessParams.outputScaleMultiplier)
	let lossLogits = rawWhiteLossProb * Double(postProcessParams.outputScaleMultiplier)
	var noResultLogits = rawWhiteNoResultProb * Double(postProcessParams.outputScaleMultiplier)
	if koRule != .simple && scoringRule != .territory {
		noResultLogits -= 100_000.0
	}
	let maxLogits = max(max(winLogits, lossLogits), noResultLogits)
	var winProb = exp(winLogits - maxLogits)
	var lossProb = exp(lossLogits - maxLogits)
	var noResultProb = exp(noResultLogits - maxLogits)
	if koRule != .simple && scoringRule != .territory {
		noResultProb = 0.0
	}
	let probSum = winProb + lossProb + noResultProb
	winProb /= probSum
	lossProb /= probSum
	noResultProb /= probSum
	let scoreMeanPreScaled = rawWhiteScoreMean * Double(postProcessParams.outputScaleMultiplier)
	let scoreStdevPreSoftplus = rawWhiteScoreMeanSq * Double(postProcessParams.outputScaleMultiplier)
	let leadPreScaled = rawWhiteLead * Double(postProcessParams.outputScaleMultiplier)
	let varTimeLeftPreSoftplus = rawVarTimeLeft * Double(postProcessParams.outputScaleMultiplier)
	let shorttermWinlossErrorPreSoftplus = rawShorttermWinlossError * Double(postProcessParams.outputScaleMultiplier)
	let shorttermScoreErrorPreSoftplus = rawShorttermScoreError * Double(postProcessParams.outputScaleMultiplier)
	var scoreMean = scoreMeanPreScaled * postProcessParams.scoreMeanMultiplier
	let scoreStdev = softPlus(scoreStdevPreSoftplus) * postProcessParams.scoreStdevMultiplier
	var scoreMeanSq = scoreMean * scoreMean + scoreStdev * scoreStdev
	var lead = leadPreScaled * postProcessParams.leadMultiplier
	let varTimeLeft = softPlus(varTimeLeftPreSoftplus) * postProcessParams.varianceTimeMultiplier
	scoreMean = scoreMean * (1.0 - noResultProb)
	scoreMeanSq = scoreMeanSq * (1.0 - noResultProb)
	lead = lead * (1.0 - noResultProb)
	let s1 = softPlus(shorttermWinlossErrorPreSoftplus * 0.5)
	let shorttermWinlossError = sqrt(s1 * s1 * postProcessParams.shorttermValueErrorMultiplier)
	let s2 = softPlus(shorttermScoreErrorPreSoftplus * 0.5)
	let shorttermScoreError = sqrt(s2 * s2 * postProcessParams.shorttermScoreErrorMultiplier)
	if nextPlayer == .black {
		let tempWin = winProb
		winProb = lossProb
		lossProb = tempWin
		scoreMean = -scoreMean
		lead = -lead
	}
	return (
		whiteWinProb: winProb,
		whiteLossProb: lossProb,
		whiteNoResultProb: noResultProb,
		whiteScoreMean: scoreMean,
		whiteScoreMeanSq: scoreMeanSq,
		whiteLead: lead,
		varTimeLeft: varTimeLeft,
		shorttermWinlossError: shorttermWinlossError,
		shorttermScoreError: shorttermScoreError
	)
}
public func postprocessPolicy(
	rawPolicy: [Float],
	board: Board,
	nextPlayer: Stone,
	postProcessParams: PostProcessParams,
	nnPolicyTemperature: Float = 1.0,
	enablePassingHacks: Bool = false
) -> [Float] {
	let policyOutputScaling = postProcessParams.outputScaleMultiplier / nnPolicyTemperature
	let policySize = 362
	var policy = Array(repeating: Float(-1e30), count: policySize)
	var maxPolicy: Float = -1e25
	for y in 0..<19 {
		for x in 0..<19 {
			let point = Point(x: x, y: y)
			let positionIndex = y * 19 + x
			let isLegal = board.isLegalMove(at: point, stone: nextPlayer)
			if isLegal && positionIndex < rawPolicy.count {
				let policyValue = rawPolicy[positionIndex] * policyOutputScaling
				policy[positionIndex] = policyValue
				if policyValue > maxPolicy {
					maxPolicy = policyValue
				}
			}
		}
	}
	let passIndex = 361
	if passIndex < rawPolicy.count {
		let policyValue = rawPolicy[passIndex] * policyOutputScaling
		policy[passIndex] = policyValue
		if policyValue > maxPolicy {
			maxPolicy = policyValue
		}
	}
	var policySum: Float = 0.0
	if enablePassingHacks {
		let maxPassPolicySumFactor: Float = 19.0
		for i in 0..<(policySize - 1) {
			if policy[i] > -1e25 {
				policy[i] = exp(policy[i] - maxPolicy)
				policySum += policy[i]
			}
		}
		let passPos = policySize - 1
		if policy[passPos] > -1e25 {
			policy[passPos] = max(1e-20, min(exp(policy[passPos] - maxPolicy), policySum * maxPassPolicySumFactor))
			policySum += policy[passPos]
		}
	} else {
		for i in 0..<policySize {
			if policy[i] > -1e25 {
				policy[i] = exp(policy[i] - maxPolicy)
				policySum += policy[i]
			}
		}
	}
	if !policySum.isFinite || policySum <= 0.0 {
		let legalCount = policy.filter { $0 > -1e25 }.count
		if legalCount > 0 {
			let uniform = 1.0 / Float(legalCount)
			for i in 0..<policySize {
				if policy[i] > -1e25 {
					policy[i] = uniform
				} else {
					policy[i] = -1.0
				}
			}
		}
	} else {
		for i in 0..<policySize {
			if policy[i] > -1e25 {
				policy[i] = policy[i] / policySum
			} else {
				policy[i] = -1.0
			}
		}
	}
	return policy
}
public func postprocessOwnership(
	rawOwnership: [Float],
	board _: Board,
	nextPlayer: Stone,
	postProcessParams: PostProcessParams
) -> [Float] {
	var ownership = Array(repeating: Float(0.0), count: 19 * 19)
	for y in 0..<19 {
		for x in 0..<19 {
			let positionIndex = y * 19 + x
			if positionIndex < rawOwnership.count {
				let rawValue = rawOwnership[positionIndex]
				let tanhValue = tanh(rawValue * postProcessParams.outputScaleMultiplier)
				if nextPlayer == .black {
					ownership[positionIndex] = -tanhValue
				} else {
					ownership[positionIndex] = tanhValue
				}
			}
		}
	}
	return ownership
}

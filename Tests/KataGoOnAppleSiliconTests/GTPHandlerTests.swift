import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Test func testGTPProtocolVersion() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("protocol_version")
	#expect(response == "= 2\n\n")
}
@Test func testGTPName() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("name")
	#expect(response == "= KataGoOnAppleSilicon\n\n")
}
@Test func testGTPVersion() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("version")
	#expect(response == "= 1.0\n\n")
}
@Test func testGTPKnownCommand() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	#expect(handler.handleCommand("known_command play") == "= true\n\n")
	#expect(handler.handleCommand("known_command unknown") == "= false\n\n")
}
@Test func testGTPListCommands() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("list_commands")
	#expect(response.starts(with: "= "))
	#expect(response.contains("play"))
	#expect(response.contains("genmove"))
}
@Test func testGTPClearBoard() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	_ = handler.handleCommand("play black A1")
	let response = handler.handleCommand("clear_board")
	#expect(response == "= \n\n")
}
@Test func testGTPPlayMove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play black A1")
	#expect(response == "= \n\n")
}
@Test func testGTPPlayInvalidMove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play black invalid")
	#expect(response == "? syntax error\n\n")
}
@Test func testGTPBoardsize() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("boardsize 19")
	#expect(response == "= \n\n")
}
@Test func testGTPKomi() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("komi 7.5")
	#expect(response == "= \n\n")
}
@Test func testGTPQuit() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("quit")
	#expect(response == "= \n\n")
}
@Test func testGTPEmptyCommand() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("")
	#expect(response == "? \n\n")
}
@Test func testGTPUnknownCommand() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("nonexistent_command")
	#expect(response == "? unknown command\n\n")
}
@Test func testGTPPlayMissingArgs() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play black")
	#expect(response == "? syntax error\n\n")
}
@Test func testGTPPlayIllegalMove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	_ = handler.handleCommand("play black A1")
	let response = handler.handleCommand("play white A1")
	#expect(response == "? illegal move\n\n")
}
@Test func testGTPPlayWhiteMove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play white T19")
	#expect(response == "= \n\n")
}
@Test func testGTPGenmoveMissingColor() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove")
	#expect(response == "? syntax error\n\n")
}
@Test func testGTPGenmoveWithModelLoaded() throws {
	let katago = KataGoInference()
	try katago.loadModel(for: "AI")
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove black")
	#expect(response.starts(with: "= "))
}
@Test func testParseMoveColumnJToT() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let responseJ = handler.handleCommand("play black J1")
	#expect(responseJ == "= \n\n")
	let responseT = handler.handleCommand("play white T1")
	#expect(responseT == "= \n\n")
}
@Test func testParseMoveInvalidColumn() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let responseZ = handler.handleCommand("play black Z1")
	#expect(responseZ == "? syntax error\n\n")
}
@Test func testParseMoveShortString() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play black A")
	#expect(response == "? syntax error\n\n")
}
@Test func testGTPGenmove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove black")
	#expect(response.starts(with: "=") || response.starts(with: "?"))
}
@Test func testParseMove() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("play black A1")
	#expect(response == "= \n\n")
}
@Test func testGTPSelectMoveColumnAToH() throws {
	let katago = KataGoInference()
	let mockModel = MockModelWithValidOutputs(targetX: 0, targetY: 0)
	katago.setModel(mockModel, for: "AI")
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove black")
	#expect(response.starts(with: "= A"))
}
@Test func testGTPSelectMoveColumnJToT() throws {
	let katago = KataGoInference()
	let mockModel = MockModelWithValidOutputs(targetX: 8, targetY: 0)
	katago.setModel(mockModel, for: "AI")
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove black")
	#expect(response.starts(with: "= J"))
}
@Test func testGTPSelectMoveColumnT() throws {
	let katago = KataGoInference()
	let mockModel = MockModelWithValidOutputs(targetX: 18, targetY: 0)
	katago.setModel(mockModel, for: "AI")
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("genmove black")
	#expect(response.starts(with: "= T"))
}
@Test func testKataSetRulesChinese() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("kata-set-rules chinese")
	#expect(response == "= \n\n")
}
@Test func testKataSetRulesUnknownPreset() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("kata-set-rules japanese")
	#expect(response == "? Unknown rules 'japanese'\n\n")
}
@Test func testKataSetRulesMissingArgument() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("kata-set-rules")
	#expect(response == "? Expected at least one argument for kata-set-rules\n\n")
}
@Test func testKataSetRulesCaseInsensitive() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("kata-set-rules CHINESE")
	#expect(response == "= \n\n")
}
@Test func testKataSetRulesKnownCommand() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	#expect(handler.handleCommand("known_command kata-set-rules") == "= true\n\n")
}
@Test func testKataSetRulesInListCommands() throws {
	let katago = KataGoInference()
	let handler = GTPHandler(katago: katago)
	let response = handler.handleCommand("list_commands")
	#expect(response.contains("kata-set-rules"))
}

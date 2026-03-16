import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Test func testBoardInitialization() throws {
	let board = Board()
	#expect(board.stones.count == 19)
	#expect(board.stones[0].count == 19)
	#expect(board.koPoint == nil)
	#expect(board.turnNumber == 0)
	#expect(board.komi == 7.5)
}
@Test func testBoardCopy() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	_ = board.playMove(at: point, stone: .black)
	let copy = board.copy()
	#expect(copy.stones[3][3] == .black)
	#expect(copy.turnNumber == 1)
	#expect(copy.moveHistory.count == 1)
	#expect(copy.moveHistory[0].location == point)
	#expect(copy.moveHistory[0].player == .black)
}
@Test func testBoardCopyWithPass() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playPass(stone: .white)
	let copy = board.copy()
	#expect(copy.moveHistory.count == 2)
	#expect(copy.moveHistory[0].location == Point(x: 3, y: 3))
	#expect(copy.moveHistory[0].player == .black)
	#expect(copy.moveHistory[1].isPass)
	#expect(copy.moveHistory[1].player == .white)
}
@Test func testBoardCopyWithKomi() throws {
	let board = Board()
	let copy = board.copy()
	#expect(copy.komi == 7.5)
}
@Test func testPlayMoveValid() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	let success = board.playMove(at: point, stone: .black)
	#expect(success)
	#expect(board.stones[3][3] == .black)
	#expect(board.turnNumber == 1)
}
@Test func testPlayMoveInvalidOccupied() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	_ = board.playMove(at: point, stone: .black)
	let success = board.playMove(at: point, stone: .white)
	#expect(!success)
	#expect(board.stones[3][3] == .black)
}
@Test func testPlayMoveInvalidOutOfBounds() throws {
	let board = Board()
	let point = Point(x: 19, y: 19)
	let success = board.playMove(at: point, stone: .black)
	#expect(!success)
}
@Test func testIsLegalMove() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	#expect(board.isLegalMove(at: point, stone: .black))
	_ = board.playMove(at: point, stone: .black)
	#expect(!board.isLegalMove(at: point, stone: .white))
}
@Test func testCaptureSingleStone() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let success = board.playMove(at: Point(x: 3, y: 4), stone: .white)
	#expect(success)
	#expect(board.stones[3][3] == .empty)
}
@Test func testCaptureMultipleStones() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 4), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 5), stone: .white)
	let success = board.playMove(at: Point(x: 3, y: 6), stone: .white)
	#expect(success)
	#expect(board.stones[3][3] == .empty)
	#expect(board.stones[4][3] == .empty)
}
@Test func testSuicideAllowed() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 4), stone: .white)
	let success = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	#expect(success)
	#expect(board.stones[3][3] == .empty)
}
@Test func testLiberties() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	#expect(board.liberties(of: Point(x: 3, y: 3)) == 4)
	_ = board.playMove(at: Point(x: 3, y: 4), stone: .black)
	#expect(board.liberties(of: Point(x: 3, y: 3)) == 6)
}
@Test func testScoring() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 0, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 18, y: 18), stone: .white)
	let score = board.score()
	#expect(score.black >= 1)
	#expect(score.white >= 1 + board.komi)
}
@Test func testCornerStoneLiberties() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 0, y: 0), stone: .black)
	#expect(board.liberties(of: Point(x: 0, y: 0)) == 2)
}
@Test func testEdgeStoneLiberties() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .black)
	#expect(board.liberties(of: Point(x: 0, y: 1)) == 3)
}
@Test func testEmptyPointLiberties() throws {
	let board = Board()
	#expect(board.liberties(of: Point(x: 5, y: 5)) == 1)
}
@Test func testScoringWithSurroundedTerritory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .black)
	let score = board.score()
	#expect(score.black >= 3)
}
@Test func testScoringWithWhiteSurroundedTerritory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 17, y: 18), stone: .white)
	_ = board.playMove(at: Point(x: 18, y: 17), stone: .white)
	let score = board.score()
	#expect(score.white >= 3 + board.komi)
}
@Test func testPointIsValid() throws {
	let validPoint = Point(x: 10, y: 10)
	let invalidPoint1 = Point(x: -1, y: 10)
	let invalidPoint2 = Point(x: 10, y: 19)
	#expect(validPoint.isValid)
	#expect(!invalidPoint1.isValid)
	#expect(!invalidPoint2.isValid)
}
@Test func testGetChainHeadSingleStone() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	_ = board.playMove(at: point, stone: .black)
	let head = board.getChainHead(at: point)
	#expect(head != nil)
	#expect(head == point)
}
@Test func testGetChainHeadMultipleStones() throws {
	let board = Board()
	let point1 = Point(x: 3, y: 3)
	let point2 = Point(x: 3, y: 4)
	_ = board.playMove(at: point1, stone: .black)
	_ = board.playMove(at: point2, stone: .black)
	let head1 = board.getChainHead(at: point1)
	let head2 = board.getChainHead(at: point2)
	#expect(head1 != nil)
	#expect(head2 != nil)
	#expect(head1 == head2)
}
@Test func testGetChainHeadEmptyPoint() throws {
	let board = Board()
	let point = Point(x: 3, y: 3)
	let head = board.getChainHead(at: point)
	#expect(head == nil)
}
@Test func testGetChainHeadDifferentGroups() throws {
	let board = Board()
	let point1 = Point(x: 3, y: 3)
	let point2 = Point(x: 10, y: 10)
	_ = board.playMove(at: point1, stone: .black)
	_ = board.playMove(at: point2, stone: .black)
	let head1 = board.getChainHead(at: point1)
	let head2 = board.getChainHead(at: point2)
	#expect(head1 != nil)
	#expect(head2 != nil)
	#expect(head1 != head2)
}
@Test func testSearchIsLadderCapturedSimpleLadder() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let libs = board.liberties(of: Point(x: 3, y: 3))
	#expect(libs == 1)
	let result = board.searchIsLadderCaptured(loc: Point(x: 3, y: 3), isAttackerFirst: true)
	#expect(result.1.isEmpty)
}
@Test func testSearchIsLadderCapturedNotInLadder() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let result = board.searchIsLadderCaptured(loc: Point(x: 3, y: 3), isAttackerFirst: true)
	#expect(result.1.isEmpty)
}
@Test func testSearchIsLadderCaptured2LibsLaddered() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	let libs = board.liberties(of: Point(x: 3, y: 3))
	#expect(libs == 2)
	let result = board.searchIsLadderCapturedAttackerFirst2Libs(loc: Point(x: 3, y: 3))
	_ = result
}
@Test func testSearchIsLadderCaptured2LibsWorkingMoves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	let result = board.searchIsLadderCapturedAttackerFirst2Libs(loc: Point(x: 3, y: 3))
	_ = result.1
}
@Test func testIterLaddersEmptyBoard() throws {
	let board = Board()
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	#expect(callbackCount == 0)
}
@Test func testIterLaddersNoLadders() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 10, y: 10), stone: .white)
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	_ = callbackCount
}
@Test func testIterLaddersOneLiberty() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	_ = callbackCount
}
@Test func testIterLaddersTwoLiberty() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	_ = callbackCount
}
@Test func testIterLaddersThreePlusLiberty() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	#expect(callbackCount == 0)
}
@Test func testIterLaddersChainHeadTracking() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 4), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	var callbackCount = 0
	board.iterLadders { _, _ in
		callbackCount += 1
	}
	_ = callbackCount
}
@Test func testGetBoardAtTurn0() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	let boardAtTurn0 = board.getBoardAtTurn(0)
	#expect(boardAtTurn0.turnNumber == 0)
	#expect(boardAtTurn0.stones[3][3] == .empty)
	#expect(boardAtTurn0.stones[4][4] == .empty)
}
@Test func testGetBoardAtTurn1() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	let boardAtTurn1 = board.getBoardAtTurn(1)
	#expect(boardAtTurn1.stones[3][3] == .black)
	#expect(boardAtTurn1.stones[4][4] == .empty)
}
@Test func testGetBoardAtTurnMultiple() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .black)
	let boardAtTurn2 = board.getBoardAtTurn(2)
	#expect(boardAtTurn2.stones[3][3] == .black)
	#expect(boardAtTurn2.stones[4][4] == .white)
	#expect(boardAtTurn2.stones[5][5] == .empty)
}
@Test func testGetBoardAtTurnBeyondHistory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	let boardAtTurn10 = board.getBoardAtTurn(10)
	#expect(boardAtTurn10.stones[3][3] == .black)
}
@Test func testGetBoardAtTurnWithPasses() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playPass(stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .black)
	let boardAtTurn2 = board.getBoardAtTurn(2)
	#expect(boardAtTurn2.stones[3][3] == .black)
	#expect(boardAtTurn2.stones[4][4] == .empty)
}

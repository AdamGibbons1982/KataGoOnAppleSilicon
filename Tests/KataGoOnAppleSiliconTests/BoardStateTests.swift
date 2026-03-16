import CoreML
import Foundation
@testable import KataGoOnAppleSilicon
import Testing
@Test func testBoardStateDirectInit() throws {
	let spatialShape: [NSNumber] = [1, 22, 19, 19]
	let spatial = try MLMultiArray(shape: spatialShape, dataType: .float16)
	let globalShape: [NSNumber] = [1, 19]
	let global = try MLMultiArray(shape: globalShape, dataType: .float16)
	let boardState = BoardState(spatial: spatial, global: global)
	#expect(boardState.spatial.count == spatial.count)
	#expect(boardState.global.count == global.count)
}
@Test func testBoardStateWithBlackStones() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	let boardState = BoardState(board: board)
	#expect(boardState.spatial.shape == [1, 22, 19, 19] as [NSNumber])
}
@Test func testBoardStateWithWhiteStones() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	let boardState = BoardState(board: board)
	#expect(boardState.spatial.shape == [1, 22, 19, 19] as [NSNumber])
}
@Test func testBoardStatePlane6KoBan() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .white)
	_ = board.playMove(at: Point(x: 0, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	#expect(board.koPoint != nil)
	#expect(board.koPoint?.x == 1)
	#expect(board.koPoint?.y == 0)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let koValue = boardState.spatial[[0, 6, 0, 1]].floatValue
	#expect(koValue == 1.0)
	let nonKoValue = boardState.spatial[[0, 6, 5, 5]].floatValue
	#expect(nonKoValue == 0.0)
}
@Test func testBoardStatePlane6NoKo() throws {
	let board = Board()
	#expect(board.koPoint == nil)
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 6, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane7KoRecaptureBlocked() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 7, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane7WithKo() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .white)
	_ = board.playMove(at: Point(x: 0, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	#expect(board.koPoint != nil)
	let boardState = BoardState(board: board, nextPlayer: .white)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 7, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane3OneLiberty() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 1), stone: .white)
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .white)
	let libertyCount = board.liberties(of: Point(x: 1, y: 1))
	#expect(libertyCount == 1)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let plane3Value = boardState.spatial[[0, 3, 1, 1]].floatValue
	#expect(plane3Value == 1.0)
	let otherValue = boardState.spatial[[0, 3, 5, 5]].floatValue
	#expect(otherValue == 0.0)
}
@Test func testBoardStatePlane4TwoLiberties() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let libertyCount = board.liberties(of: Point(x: 2, y: 2))
	#expect(libertyCount == 2)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let plane4Value = boardState.spatial[[0, 4, 2, 2]].floatValue
	#expect(plane4Value == 1.0)
	let otherValue = boardState.spatial[[0, 4, 5, 5]].floatValue
	#expect(otherValue == 0.0)
}
@Test func testBoardStatePlane5ThreeLiberties() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 2), stone: .white)
	let libertyCount = board.liberties(of: Point(x: 2, y: 2))
	#expect(libertyCount == 3)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let plane5Value = boardState.spatial[[0, 5, 2, 2]].floatValue
	#expect(plane5Value == 1.0)
	let otherValue = boardState.spatial[[0, 5, 5, 5]].floatValue
	#expect(otherValue == 0.0)
}
@Test func testBoardStatePlane1WithWhiteNextPlayer() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let whiteStone1 = boardState.spatial[[0, 1, 3, 3]].floatValue
	#expect(whiteStone1 == 1.0)
	let whiteStone2 = boardState.spatial[[0, 1, 5, 5]].floatValue
	#expect(whiteStone2 == 1.0)
	let blackStone = boardState.spatial[[0, 2, 4, 4]].floatValue
	#expect(blackStone == 1.0)
	let emptyPlane1 = boardState.spatial[[0, 1, 0, 0]].floatValue
	#expect(emptyPlane1 == 0.0)
	let emptyPlane2 = boardState.spatial[[0, 2, 0, 0]].floatValue
	#expect(emptyPlane2 == 0.0)
}
@Test func testBoardStatePlanes1And2PerspectiveSwitching() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	let boardStateBlack = BoardState(board: board, nextPlayer: .black)
	#expect(boardStateBlack.spatial[[0, 1, 2, 2]].floatValue == 1.0)
	#expect(boardStateBlack.spatial[[0, 2, 3, 3]].floatValue == 1.0)
	let boardStateWhite = BoardState(board: board, nextPlayer: .white)
	#expect(boardStateWhite.spatial[[0, 1, 3, 3]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 2, 2, 2]].floatValue == 1.0)
}
@Test func testBoardStateGlobalKomiBlackToMove() throws {
	let board = Board()
	let komi: Float = 7.5
	let boardState = BoardState(board: board, nextPlayer: .black, komi: komi)
	let expectedKomi = -komi / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(actualKomi == expectedKomi)
	#expect(actualKomi == -0.375)
}
@Test func testBoardStateGlobalKomiWhiteToMove() throws {
	let board = Board()
	let komi: Float = 7.5
	let boardState = BoardState(board: board, nextPlayer: .white, komi: komi)
	let expectedKomi = komi / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(actualKomi == expectedKomi)
	#expect(actualKomi == 0.375)
}
@Test func testBoardStateGlobalKomiCustomValue() throws {
	let board = Board()
	let customKomi: Float = 6.5
	let boardState = BoardState(board: board, nextPlayer: .black, komi: customKomi)
	let expectedKomi = -customKomi / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(abs(actualKomi - expectedKomi) < 0.0001)
	#expect(abs(actualKomi - (-0.325)) < 0.0001)
}
@Test func testBoardStateGlobalKomiClippingLarge() throws {
	let board = Board()
	let largeKomi: Float = 500.0
	let boardState = BoardState(board: board, nextPlayer: .white, komi: largeKomi)
	let expectedKomi: Float = 381.0 / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(abs(actualKomi - expectedKomi) < 0.01)
	#expect(abs(actualKomi - 19.05) < 0.01)
}
@Test func testBoardStateGlobalKomiClippingLargeNegative() throws {
	let board = Board()
	let largeNegativeKomi: Float = -500.0
	let boardState = BoardState(board: board, nextPlayer: .black, komi: largeNegativeKomi)
	let expectedKomi: Float = 381.0 / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(abs(actualKomi - expectedKomi) < 0.01)
	#expect(abs(actualKomi - 19.05) < 0.01)
}
@Test func testBoardStateGlobalKomiClippingNegative() throws {
	let board = Board()
	let largeNegativeKomi: Float = -500.0
	let boardState = BoardState(board: board, nextPlayer: .white, komi: largeNegativeKomi)
	let expectedKomi: Float = -381.0 / 20.0
	let actualKomi = boardState.global[5].floatValue
	#expect(abs(actualKomi - expectedKomi) < 0.01)
	#expect(abs(actualKomi - (-19.05)) < 0.01)
}
@Test func testBoardStatePlanes18And19EmptyBoard() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let plane18Value = boardState.spatial[[0, 18, NSNumber(value: y), NSNumber(value: x)]].floatValue
			let plane19Value = boardState.spatial[[0, 19, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(plane18Value == 0.0)
			#expect(plane19Value == 0.0)
		}
	}
}
@Test func testBoardStatePlanes18And19WithStones() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let blackStonePlane18 = boardState.spatial[[0, 18, 3, 3]].floatValue
	#expect(blackStonePlane18 == 1.0)
	let whiteStonePlane19 = boardState.spatial[[0, 19, 5, 5]].floatValue
	#expect(whiteStonePlane19 == 1.0)
	let blackStonePlane19 = boardState.spatial[[0, 19, 3, 3]].floatValue
	#expect(blackStonePlane19 == 0.0)
	let whiteStonePlane18 = boardState.spatial[[0, 18, 5, 5]].floatValue
	#expect(whiteStonePlane18 == 0.0)
}
@Test func testBoardStatePlanes18And19PerspectiveSwitching() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	let boardStateBlack = BoardState(board: board, nextPlayer: .black)
	#expect(boardStateBlack.spatial[[0, 18, 2, 2]].floatValue == 1.0)
	#expect(boardStateBlack.spatial[[0, 19, 3, 3]].floatValue == 1.0)
	let boardStateWhite = BoardState(board: board, nextPlayer: .white)
	#expect(boardStateWhite.spatial[[0, 18, 3, 3]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 19, 2, 2]].floatValue == 1.0)
}
@Test func testBoardStatePlanes18And19SurroundedTerritory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let territoryPlane18 = boardState.spatial[[0, 18, 0, 0]].floatValue
	#expect(territoryPlane18 == 1.0)
	#expect(boardState.spatial[[0, 18, 0, 1]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 1, 0]].floatValue == 1.0)
}
@Test func testBoardStatePlanes18And19WhiteSurroundedTerritory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 17, y: 18), stone: .white)
	_ = board.playMove(at: Point(x: 18, y: 17), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let territoryPlane18 = boardState.spatial[[0, 18, 18, 18]].floatValue
	#expect(territoryPlane18 == 1.0)
	#expect(boardState.spatial[[0, 18, 18, 17]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 17, 18]].floatValue == 1.0)
}
@Test func testBoardStatePlanes18And19MixedScenario() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .black)
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 17, y: 18), stone: .white)
	_ = board.playMove(at: Point(x: 18, y: 17), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 18, 0, 0]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 0, 1]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 1, 0]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 18, 18]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 18, 17]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 17, 18]].floatValue == 1.0)
}
@Test func testBoardStatePlanes18And19MultipleStones() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .black)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .white)
	_ = board.playMove(at: Point(x: 6, y: 6), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 18, 3, 3]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 4, 4]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 5, 5]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 6, 6]].floatValue == 1.0)
}
@Test func testBoardStatePlanes18And19LargeTerritory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 1, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let territoryPlane18 = boardState.spatial[[0, 18, 2, 2]].floatValue
	#expect(territoryPlane18 == 1.0)
}
@Test func testBoardStatePlanes18And19WithOpponentStonesInRegion() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 18, 1, 1]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 19, 1, 1]].floatValue == 0.0)
	#expect(boardState.spatial[[0, 19, 2, 2]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 18, 2, 2]].floatValue == 0.0)
}
@Test func testBoardStatePlanes9To13EmptyBoard() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for plane in 9...13 {
		for y in 0..<19 {
			for x in 0..<19 {
				let value = boardState.spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]].floatValue
				#expect(value == 0.0)
			}
		}
	}
	for i in 0..<5 {
		#expect(boardState.global[i].floatValue == 0.0)
	}
}
@Test func testBoardStatePlane9SingleMove() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let plane9Value = boardState.spatial[[0, 9, 3, 3]].floatValue
	#expect(plane9Value == 1.0)
	let otherValue = boardState.spatial[[0, 9, 5, 5]].floatValue
	#expect(otherValue == 0.0)
	for plane in 10...13 {
		let value = boardState.spatial[[0, NSNumber(value: plane), 3, 3]].floatValue
		#expect(value == 0.0)
	}
}
@Test func testBoardStatePlanes9To13MultipleMoves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .black)
	_ = board.playMove(at: Point(x: 7, y: 7), stone: .white)
	_ = board.playMove(at: Point(x: 9, y: 9), stone: .black)
	_ = board.playMove(at: Point(x: 11, y: 11), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 9, 11, 11]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 10, 9, 9]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 11, 7, 7]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 12, 5, 5]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 13, 3, 3]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 9, 3, 3]].floatValue == 0.0)
	#expect(boardState.spatial[[0, 10, 11, 11]].floatValue == 0.0)
}
@Test func testBoardStatePlanes9To13LessThan5Moves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	#expect(boardState.spatial[[0, 9, 5, 5]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 10, 3, 3]].floatValue == 1.0)
	for plane in 11...13 {
		let value = boardState.spatial[[0, NSNumber(value: plane), 3, 3]].floatValue
		#expect(value == 0.0)
	}
}
@Test func testBoardStatePlanes9To13PassMoves() throws {
	let board = Board()
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.global[0].floatValue == 1.0)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 9, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
	for i in 1..<5 {
		#expect(boardState.global[i].floatValue == 0.0)
	}
}
@Test func testBoardStatePlanes9To13MultiplePasses() throws {
	let board = Board()
	_ = board.playPass(stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	for i in 0..<5 {
		#expect(boardState.global[i].floatValue == 1.0)
	}
	for plane in 9...13 {
		for y in 0..<19 {
			for x in 0..<19 {
				let value = boardState.spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]].floatValue
				#expect(value == 0.0)
			}
		}
	}
}
@Test func testBoardStatePlanes9To13MixedMovesAndPasses() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playMove(at: Point(x: 7, y: 7), stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playMove(at: Point(x: 11, y: 11), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 9, 11, 11]].floatValue == 1.0)
	#expect(boardState.global[1].floatValue == 1.0)
	#expect(boardState.spatial[[0, 11, 7, 7]].floatValue == 1.0)
	#expect(boardState.global[3].floatValue == 1.0)
	#expect(boardState.spatial[[0, 13, 3, 3]].floatValue == 1.0)
	#expect(boardState.global[0].floatValue == 0.0)
	#expect(boardState.global[2].floatValue == 0.0)
	#expect(boardState.global[4].floatValue == 0.0)
	#expect(boardState.spatial[[0, 10, 5, 5]].floatValue == 0.0)
	#expect(boardState.spatial[[0, 12, 5, 5]].floatValue == 0.0)
}
@Test func testBoardStatePlanes9To13HistoryAlternation() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .black)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	#expect(boardState.spatial[[0, 9, 5, 5]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 10, 4, 4]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 11, 3, 3]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 12, 2, 2]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 13, 1, 1]].floatValue == 1.0)
}
@Test func testBoardStatePlanes9To13PerspectiveSwitching() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .black)
	let boardStateBlack = BoardState(board: board, nextPlayer: .black)
	for plane in 9...13 {
		let value = boardStateBlack.spatial[[0, NSNumber(value: plane), 5, 5]].floatValue
		#expect(value == 0.0)
	}
	let boardStateWhite = BoardState(board: board, nextPlayer: .white)
	#expect(boardStateWhite.spatial[[0, 9, 5, 5]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 10, 4, 4]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 11, 3, 3]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 12, 2, 2]].floatValue == 1.0)
	#expect(boardStateWhite.spatial[[0, 13, 1, 1]].floatValue == 1.0)
}
@Test func testBoardStatePlanes9To13WrongPlayerSequence() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 5, y: 5), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	#expect(boardState.spatial[[0, 9, 5, 5]].floatValue == 1.0)
	#expect(boardState.spatial[[0, 10, 3, 3]].floatValue == 0.0)
}
@Test func testBoardStatePlane14EmptyBoard() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 14, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane14NoLadders() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 10, y: 10), stone: .white)
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 14, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane14SimpleLadder() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .white)
	_ = boardState.spatial[[0, 14, 3, 3]].floatValue
}
@Test func testBoardStatePlane15NoHistory() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 15, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane15WithHistory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 10, y: 10), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	_ = boardState.spatial[[0, 15, 3, 3]].floatValue
}
@Test func testBoardStatePlane16NoHistory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 16, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane16WithHistory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	_ = board.playMove(at: Point(x: 10, y: 10), stone: .black)
	_ = board.playMove(at: Point(x: 11, y: 11), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	_ = boardState.spatial[[0, 16, 3, 3]].floatValue
}
@Test func testBoardStatePlane17EmptyBoard() throws {
	let board = Board()
	let boardState = BoardState(board: board)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 17, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane17NoWorkingMoves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .white)
	for y in 0..<19 {
		for x in 0..<19 {
			let value = boardState.spatial[[0, 17, NSNumber(value: y), NSNumber(value: x)]].floatValue
			#expect(value == 0.0)
		}
	}
}
@Test func testBoardStatePlane17WithWorkingMoves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let value1 = boardState.spatial[[0, 17, NSNumber(value: 2), NSNumber(value: 3)]].floatValue
	let value2 = boardState.spatial[[0, 17, NSNumber(value: 4), NSNumber(value: 3)]].floatValue
	#expect(value1 == 1.0, "Feature 17 should be non-zero at working move location (3, 2)")
	#expect(value2 == 1.0, "Feature 17 should be non-zero at working move location (3, 4)")
	let stoneValue = boardState.spatial[[0, 17, NSNumber(value: 3), NSNumber(value: 3)]].floatValue
	#expect(stoneValue == 0.0, "Feature 17 should be zero at the stone location")
}
@Test func testBoardStateLadderFeaturesAllZero() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 10, y: 10), stone: .white)
	let boardState = BoardState(board: board)
	for plane in 14...17 {
		for y in 0..<19 {
			for x in 0..<19 {
				let value = boardState.spatial[[0, NSNumber(value: plane), NSNumber(value: y), NSNumber(value: x)]].floatValue
				#expect(value == 0.0)
			}
		}
	}
}
@Test func testBoardStateLadderFeaturesComplete() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .white)
	_ = boardState.spatial[[0, 14, 3, 3]].floatValue
	_ = boardState.spatial[[0, 15, 3, 3]].floatValue
	_ = boardState.spatial[[0, 16, 3, 3]].floatValue
	_ = boardState.spatial[[0, 17, 3, 3]].floatValue
}
@Test func testBoardStateLadderFeaturesInsufficientHistory() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	let boardState = BoardState(board: board)
	_ = boardState.spatial[[0, 15, 3, 3]].floatValue
	_ = boardState.spatial[[0, 16, 3, 3]].floatValue
}
@Test func testBoardStateLadderFeaturesPassMoves() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	_ = boardState.spatial[[0, 14, 3, 3]].floatValue
	_ = boardState.spatial[[0, 15, 3, 3]].floatValue
}
@Test func testBoardStateLadderFeaturesPerspective() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 2, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 4, y: 3), stone: .white)
	_ = board.playMove(at: Point(x: 3, y: 2), stone: .white)
	let boardStateBlack = BoardState(board: board, nextPlayer: .black)
	let boardStateWhite = BoardState(board: board, nextPlayer: .white)
	_ = boardStateBlack.spatial[[0, 14, 3, 3]].floatValue
	_ = boardStateWhite.spatial[[0, 14, 3, 3]].floatValue
}
@Test func testGlobalFeature14EmptyBoard() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 0.0)
}
@Test func testGlobalFeature14OnePass() throws {
	let board = Board()
	_ = board.playPass(stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14TwoConsecutivePasses() throws {
	let board = Board()
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14PassAfterRegularMove() throws {
	let board = Board()
	_ = board.playPass(stone: .black)
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .white)
	_ = board.playPass(stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14ThreeConsecutivePasses() throws {
	let board = Board()
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	_ = board.playPass(stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14BlackPerspective() throws {
	let board = Board()
	_ = board.playPass(stone: .white)
	_ = board.playPass(stone: .black)
	let boardState = BoardState(board: board, nextPlayer: .white)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14WhitePerspective() throws {
	let board = Board()
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14MovesThenPasses() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
	_ = board.playMove(at: Point(x: 4, y: 4), stone: .white)
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature14SpightStyleEnding() throws {
	let board = Board()
	_ = board.playMove(at: Point(x: 1, y: 1), stone: .black)
	_ = board.playMove(at: Point(x: 0, y: 1), stone: .white)
	_ = board.playMove(at: Point(x: 2, y: 1), stone: .white)
	_ = board.playMove(at: Point(x: 1, y: 0), stone: .white)
	_ = board.playMove(at: Point(x: 1, y: 2), stone: .black)
	_ = board.playPass(stone: .black)
	_ = board.playPass(stone: .white)
	let boardState = BoardState(board: board, nextPlayer: .black)
	let feature14 = boardState.global[14].floatValue
	#expect(feature14 == 1.0)
}
@Test func testGlobalFeature18BasicKomiZero() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 0.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18BasicKomiHalf() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 0.5)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.5) < 0.0001)
}
@Test func testGlobalFeature18BasicKomiOne() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 1.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18BasicKomiOneAndHalf() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 1.5)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - (-0.5)) < 0.0001)
}
@Test func testGlobalFeature18BasicKomiTwo() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 2.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18BasicKomiSevenAndHalf() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 7.5)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - (-0.5)) < 0.0001)
}
@Test func testGlobalFeature18WaveBoundaryDeltaZero() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: 1.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18WaveBoundaryDeltaHalf() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .white, komi: 1.5)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.5) < 0.0001)
}
@Test func testGlobalFeature18WaveBoundaryDeltaOneAndHalf() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .white, komi: 2.5)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - (-0.5)) < 0.0001)
}
@Test func testGlobalFeature18WaveBoundaryDeltaTwo() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .white, komi: 3.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18PerspectiveBlackVsWhite() throws {
	let board = Board()
	let boardStateBlack = BoardState(board: board, nextPlayer: .black, komi: 0.5)
	let boardStateWhite = BoardState(board: board, nextPlayer: .white, komi: 0.5)
	let feature18Black = boardStateBlack.global[18].floatValue
	let feature18White = boardStateWhite.global[18].floatValue
	#expect(abs(feature18Black - feature18White) > 0.1)
}
@Test func testGlobalFeature18PerspectiveSymmetry() throws {
	let board = Board()
	let boardStateBlack = BoardState(board: board, nextPlayer: .black, komi: 1.0)
	let boardStateWhite = BoardState(board: board, nextPlayer: .white, komi: 1.0)
	let feature18Black = boardStateBlack.global[18].floatValue
	let feature18White = boardStateWhite.global[18].floatValue
	#expect(abs(feature18Black - feature18White) < 0.0001)
}
@Test func testGlobalFeature18ExtremeKomiPositive() throws {
	let board = Board()
	let extremeKomi: Float = 100.0
	let boardState = BoardState(board: board, nextPlayer: .white, komi: extremeKomi)
	let feature18 = boardState.global[18].floatValue
	#expect(feature18 >= -0.5)
	#expect(feature18 <= 0.5)
}
@Test func testGlobalFeature18ExtremeKomiNegative() throws {
	let board = Board()
	let extremeKomi: Float = -100.0
	let boardState = BoardState(board: board, nextPlayer: .black, komi: extremeKomi)
	let feature18 = boardState.global[18].floatValue
	#expect(feature18 >= -0.5)
	#expect(feature18 <= 0.5)
}
@Test func testGlobalFeature18TriangularWaveShape() throws {
	let board = Board()
	let boardState1 = BoardState(board: board, nextPlayer: .white, komi: 1.5)
	let wave1 = boardState1.global[18].floatValue
	#expect(abs(wave1 - 0.5) < 0.0001)
	let boardState2 = BoardState(board: board, nextPlayer: .white, komi: 2.5)
	let wave2 = boardState2.global[18].floatValue
	#expect(abs(wave2 - (-0.5)) < 0.0001)
	let boardState3 = BoardState(board: board, nextPlayer: .white, komi: 2.0)
	let wave3 = boardState3.global[18].floatValue
	#expect(abs(wave3 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18NegativeKomi() throws {
	let board = Board()
	let boardState = BoardState(board: board, nextPlayer: .black, komi: -1.0)
	let feature18 = boardState.global[18].floatValue
	#expect(abs(feature18 - 0.0) < 0.0001)
}
@Test func testGlobalFeature18MultipleKomiValues() throws {
	let board = Board()
	let komiValues: [Float] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 7.5]
	for komi in komiValues {
		let boardState = BoardState(board: board, nextPlayer: .white, komi: komi)
		let feature18 = boardState.global[18].floatValue
		#expect(feature18 >= -0.5)
		#expect(feature18 <= 0.5)
	}
}

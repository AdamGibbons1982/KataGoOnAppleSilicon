import Testing
import Foundation
import CoreML
@testable import KataGoOnAppleSilicon

// MARK: - Ko detection vs. KataGo's rule (snapback)
//
// KataGo only sets a ko ban when all three hold (cpp/game/board.cpp,
// Board::playMoveAssumeLegal, just after the capture loop):
//
//   //We have a ko if 1 stone was captured and the capturing move is one isolated stone
//   //And the capturing move itself now only has one liberty
//   if(num_captured == 1 && chain_data[chain_head[loc]].num_locs == 1
//      && chain_data[chain_head[loc]].num_liberties == 1)
//     ko_loc = possible_ko_loc;
//
// Board.playMove checks only the first condition, so any single-stone capture
// bans the captured point for one move. In a snapback this refuses a legal
// recapture: `play` answers "? illegal move", and a client that replays the
// game move by move can no longer get past that point.
//
// Snapback position (5x5), reached by legal alternating play:
//
//   3  O O O . X
//   2  X X X O .
//   1  X O . X O
//      A B C D E
//
// Black C1 captures the single white stone at B1. Black's capturing stone
// joins a six-stone group whose only liberty is B1, so White B1 captures all
// six. That is a snapback, not a ko, and it is legal under every rule set.
// KataGo's own Board accepts it: after Black C1, ko_loc is NULL_LOC.

/// (x, y, stone), with x = column (A = 0) and y = row (1 = 0), as in `Point`.
private func snapbackMoves() -> [(Int, Int, Stone)] {
    [
        (0, 0, .black), (1, 0, .white),   // A1, B1
        (0, 1, .black), (0, 2, .white),   // A2, A3
        (1, 1, .black), (1, 2, .white),   // B2, B3
        (2, 1, .black), (2, 2, .white),   // C2, C3
        (3, 0, .black), (3, 1, .white),   // D1, D2
        (4, 2, .black), (4, 0, .white),   // E3, E1
    ]
}

private func makeSnapbackBoard() -> Board {
    let board = Board(size: 5)
    for (x, y, stone) in snapbackMoves() {
        let played = board.playMove(at: Point(x: x, y: y), stone: stone)
        #expect(played, "setup move (\(x), \(y)) was refused")
    }
    return board
}

private func stoneCount(_ stone: Stone, on board: Board) -> Int {
    board.stones.joined().filter { $0 == stone }.count
}

@Test func testSnapbackCaptureDoesNotSetKoPoint() async throws {
    let board = makeSnapbackBoard()
    #expect(board.playMove(at: Point(x: 2, y: 0), stone: .black))   // Black C1
    #expect(board.stones[0][1] == .empty)                            // White B1 captured
    // The capturing stone joined a larger group, so this is not a ko.
    #expect(board.koPoint == nil)
}

@Test func testSnapbackRecaptureIsLegal() async throws {
    let board = makeSnapbackBoard()
    #expect(board.playMove(at: Point(x: 2, y: 0), stone: .black))   // Black C1
    let blackBefore = stoneCount(.black, on: board)

    let snapback = Point(x: 1, y: 0)                                  // White B1
    #expect(board.isLegalMove(at: snapback, stone: .white))
    #expect(board.playMove(at: snapback, stone: .white))
    #expect(stoneCount(.black, on: board) == blackBefore - 6)
}

@Test func testSnapbackRecaptureIsLegalViaGTP() async throws {
    let handler = GTPHandler(katago: KataGoInference())
    let columns = Array("ABCDE")
    #expect(handler.handleCommand("boardsize 5").hasPrefix("="))
    #expect(handler.handleCommand("clear_board").hasPrefix("="))
    for (x, y, stone) in snapbackMoves() {
        let color = stone == .black ? "black" : "white"
        #expect(handler.handleCommand("play \(color) \(columns[x])\(y + 1)").hasPrefix("="))
    }
    #expect(handler.handleCommand("play black C1").hasPrefix("="))
    let response = handler.handleCommand("play white B1")
    #expect(response.hasPrefix("="), "snapback refused: \(response)")
}

@Test func testSnapbackCaptureLeavesKoBanPlaneEmpty() async throws {
    let board = makeSnapbackBoard()
    #expect(board.playMove(at: Point(x: 2, y: 0), stone: .black))   // Black C1
    let boardState = BoardState(board: board, nextPlayer: .white)
    // Plane 6 is the ko-ban feature; spatial is indexed [batch, plane, y, x].
    #expect(boardState.spatial[[0, 6, 0, 1]].floatValue == 0.0)
}

// An isolated capturing stone that keeps more than one liberty is not a ko
// either (KataGo's third condition). Here White could not retake at B1
// anyway: it would be suicide.
@Test func testIsolatedCaptureWithSeveralLibertiesDoesNotSetKoPoint() async throws {
    let board = Board()
    _ = board.playMove(at: Point(x: 1, y: 0), stone: .white)
    _ = board.playMove(at: Point(x: 0, y: 0), stone: .black)
    _ = board.playMove(at: Point(x: 2, y: 0), stone: .black)
    #expect(board.playMove(at: Point(x: 1, y: 1), stone: .black))   // captures B1, keeps 3 liberties
    #expect(board.stones[0][1] == .empty)
    #expect(board.koPoint == nil)
}

// Control: a real ko must still be banned, before and after any fix.
//
//   3  . X O .
//   2  X O . O      Black C2 captures White B2. The capturing stone is
//   1  . X O .      isolated with one liberty (B2): a ko.
//      A B C D
@Test func testGenuineKoIsStillBanned() async throws {
    let board = Board(size: 4)
    let moves: [(Int, Int, Stone)] = [
        (1, 2, .black), (2, 2, .white),
        (0, 1, .black), (3, 1, .white),
        (1, 0, .black), (2, 0, .white),
        (3, 3, .black), (1, 1, .white),
    ]
    for (x, y, stone) in moves {
        #expect(board.playMove(at: Point(x: x, y: y), stone: stone))
    }
    #expect(board.playMove(at: Point(x: 2, y: 1), stone: .black))   // Black C2 takes the ko
    #expect(board.koPoint == Point(x: 1, y: 1))
    #expect(!board.isLegalMove(at: Point(x: 1, y: 1), stone: .white))
    #expect(!board.playMove(at: Point(x: 1, y: 1), stone: .white))

    let boardState = BoardState(board: board, nextPlayer: .white)
    #expect(boardState.spatial[[0, 6, 1, 1]].floatValue == 1.0)
}

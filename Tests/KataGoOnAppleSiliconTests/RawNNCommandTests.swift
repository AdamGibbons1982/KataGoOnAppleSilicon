import Testing
import Foundation
import CoreML
@testable import KataGoOnAppleSilicon

// MARK: - RawNN Command Tests

@Test func testRawNNEmptyBoard() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    // Verify output contains expected sections
    #expect(output.contains("symmetry 0"))
    #expect(output.contains("whiteWin"))
    #expect(output.contains("whiteLoss"))
    #expect(output.contains("noResult"))
    #expect(output.contains("whiteLead"))
    #expect(output.contains("policy"))
    #expect(output.contains("policyPass"))
    #expect(output.contains("whiteOwnership"))
}

@Test func testRawNNOutputFormat() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    let lines = output.components(separatedBy: .newlines)
    
    // Check that we have the expected structure
    // Should have: symmetry, value outputs, policy header, 19 policy lines, policyPass, ownership header, 19 ownership lines, empty line
    var hasSymmetry = false
    var hasPolicyHeader = false
    var hasPolicyPass = false
    var hasOwnershipHeader = false
    var policyLineCount = 0
    var ownershipLineCount = 0
    
    for line in lines {
        if line.hasPrefix("symmetry ") {
            hasSymmetry = true
        } else if line == "policy" {
            hasPolicyHeader = true
        } else if line.hasPrefix("policyPass ") {
            hasPolicyPass = true
        } else if line == "whiteOwnership" {
            hasOwnershipHeader = true
        } else if hasPolicyHeader && !hasPolicyPass && !line.isEmpty {
            // Count policy lines (should be 19)
            let values = line.split(separator: " ")
            if values.count == 19 {
                policyLineCount += 1
            }
        } else if hasOwnershipHeader && !line.isEmpty {
            // Count ownership lines (should be 19)
            let values = line.split(separator: " ")
            if values.count == 19 {
                ownershipLineCount += 1
            }
        }
    }
    
    #expect(hasSymmetry)
    #expect(hasPolicyHeader)
    #expect(hasPolicyPass)
    #expect(hasOwnershipHeader)
    #expect(policyLineCount == 19)
    #expect(ownershipLineCount == 19)
}

@Test func testRawNNSymmetry() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    // Test different symmetry values
    for symmetry in 0..<8 {
        let output = try katago.rawNN(
            board: board,
            boardState: boardState,
            profile: "test",
            whichSymmetry: symmetry
        )
        
        #expect(output.contains("symmetry \(symmetry)"))
    }
}

@Test func testRawNNValueExtraction() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    // Verify value outputs are present and formatted correctly
    let lines = output.components(separatedBy: .newlines)
    
    var hasWhiteWin = false
    var hasWhiteLoss = false
    var hasNoResult = false
    var hasWhiteLead = false
    
    for line in lines {
        if line.hasPrefix("whiteWin ") {
            hasWhiteWin = true
            // Verify format: "whiteWin %.6f"
            let parts = line.split(separator: " ")
            #expect(parts.count == 2)
            if let value = Float(parts[1]) {
                #expect(value >= 0.0 && value <= 1.0)
            }
        } else if line.hasPrefix("whiteLoss ") {
            hasWhiteLoss = true
        } else if line.hasPrefix("noResult ") {
            hasNoResult = true
        } else if line.hasPrefix("whiteLead ") {
            hasWhiteLead = true
        }
    }
    
    #expect(hasWhiteWin)
    #expect(hasWhiteLoss)
    #expect(hasNoResult)
    #expect(hasWhiteLead)
}

@Test func testRawNNPolicyGridFormatting() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    // Extract policy section
    let lines = output.components(separatedBy: .newlines)
    var inPolicySection = false
    var policyLines: [String] = []
    
    for line in lines {
        if line == "policy" {
            inPolicySection = true
            continue
        }
        if line.hasPrefix("policyPass ") {
            break
        }
        if inPolicySection && !line.isEmpty {
            policyLines.append(line)
        }
    }
    
    // Should have 19 lines
    #expect(policyLines.count == 19)
    
    // Each line should have 19 values formatted as %8.6f
    for line in policyLines {
        let values = line.split(separator: " ")
        #expect(values.count == 19)
        
        // Verify format (each value should be 8 characters with decimal point)
        for valueStr in values {
            // Should be parseable as float
            #expect(Float(valueStr) != nil || valueStr.trimmingCharacters(in: .whitespaces) == "NAN")
        }
    }
}

@Test func testRawNNOwnershipGridFormatting() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    // Extract ownership section
    let lines = output.components(separatedBy: .newlines)
    var inOwnershipSection = false
    var ownershipLines: [String] = []
    
    for line in lines {
        if line == "whiteOwnership" {
            inOwnershipSection = true
            continue
        }
        if inOwnershipSection && !line.isEmpty {
            ownershipLines.append(line)
        } else if inOwnershipSection && line.isEmpty {
            break
        }
    }
    
    // Should have 19 lines
    #expect(ownershipLines.count == 19)
    
    // Each line should have 19 values formatted as %9.7f
    for line in ownershipLines {
        let values = line.split(separator: " ")
        #expect(values.count == 19)
        
        // Verify format (each value should be parseable as float)
        for valueStr in values {
            #expect(Float(valueStr) != nil || valueStr.trimmingCharacters(in: .whitespaces) == "NAN")
        }
    }
}

@Test func testRawNNWithHumanModel() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0,
        useHumanModel: true
    )
    
    // Human model format should have whiteScore and whiteScoreSq instead of whiteLead, whiteScoreSelfplay, etc.
    #expect(output.contains("whiteScore"))
    #expect(output.contains("whiteScoreSq"))
    #expect(!output.contains("whiteLead"))
    #expect(!output.contains("whiteScoreSelfplay"))
}

@Test func testRawNNWithSingleMove() async throws {
    let katago = KataGoInference()
    let mockModel = MockModelWithValidOutputs()
    katago.setModel(mockModel, for: "test")
    
    let board = Board()
    _ = board.playMove(at: Point(x: 3, y: 3), stone: .black)
    let boardState = BoardState(board: board)
    
    let output = try katago.rawNN(
        board: board,
        boardState: boardState,
        profile: "test",
        whichSymmetry: 0
    )
    
    // Should still produce valid output
    #expect(output.contains("symmetry 0"))
    #expect(output.contains("policy"))
    #expect(output.contains("whiteOwnership"))
}

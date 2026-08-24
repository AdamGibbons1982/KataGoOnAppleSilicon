import Testing
import Foundation
import CoreML
@testable import KataGoOnAppleSilicon

// MARK: - Fork Invariants
//
// These tests guard the edits this fork must carry on top of upstream. They
// exist because the sync procedure is "reset to upstream/master and reapply the
// fork changes", and a silently dropped change does not fail a build — it ships
// an app whose AI cannot move.
//
// On 2026-08-24 a sync lost four of them at once. The package's 353 tests all
// passed, because every test that touches a real model fails on model absence
// anyway, and the mocks do not exercise the dispatch (see the note on
// usesNewNaming below). The bug reached the simulator instead.
//
// They assert PRESENCE of source properties, not Go logic, and they run with no
// model weights available. Each failure names the fork change that is missing.
// See /sync-upstream for the numbered list.
//
// What these CANNOT catch: a mis-converted .mlpackage. The model is data, not
// source — `optimize_identity_mask=true` produces a model that accepts a correct
// mask and silently ignores it. That needs the 9x9/13x13/19x19 simulator check.

private func engineSource(_ name: String) throws -> String {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.pathComponents.count > 1 && dir.lastPathComponent != "Tests" {
        dir = dir.deletingLastPathComponent()
    }
    let root = dir.deletingLastPathComponent()
    let url = root
        .appendingPathComponent("Sources/KataGoOnAppleSilicon")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}

private func packageManifest() throws -> String {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.pathComponents.count > 1 && dir.lastPathComponent != "Tests" {
        dir = dir.deletingLastPathComponent()
    }
    let root = dir.deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
}

// MARK: - Fork change 1 & 2: Package.swift

@Test func forkChange1_packageDeclaresAppPlatforms() throws {
    let manifest = try packageManifest()
    #expect(
        manifest.contains(".macCatalyst(.v26)"),
        "Fork change 1 missing: Package.swift must declare .macCatalyst(.v26) — the Goban3D build requires it."
    )
    #expect(
        manifest.contains(".iOS(.v26)"),
        "Fork change 1 missing: Package.swift must declare .iOS(.v26) to match Goban3D's deployment floor."
    )
}

@Test func forkChange2_resourcesUseProcessNotCopy() throws {
    let manifest = try packageManifest()
    #expect(
        manifest.contains(#".process("Models/Resources")"#),
        """
        Fork change 2 missing: Models/Resources must use .process, not .copy.
        .copy nests the directory inside the resource bundle, which is not a \
        signable iOS bundle — CodeSign fails with "bundle format unrecognized" \
        and the whole Goban3D app build fails. swift build/test never codesign, \
        so only an app build catches this.
        """
    )
    #expect(
        !manifest.contains(#".copy("Models/Resources")"#),
        "Fork change 2 violated: Models/Resources is declared .copy — see above."
    )
}

// MARK: - Fork change 4: ModelLoader

@Test func forkChange4_modelLoaderPrefersBundleMain() throws {
    let source = try engineSource("Models/ModelLoader.swift")
    #expect(
        source.contains("Bundle.main"),
        """
        Fork change 4 missing: ModelLoader must try Bundle.main/.mlmodelc first. \
        The models ship in the Goban3D app target, not in this package, and Xcode \
        compiles them into Bundle.main — upstream's Bundle.module lookup can never \
        see them and fails at runtime in the app.
        """
    )
    #expect(
        source.contains("mlmodelc"),
        "Fork change 4 missing: ModelLoader must look for the .mlmodelc compiled by Xcode."
    )
    #expect(
        source.contains("Bundle.module"),
        "Upstream's Bundle.module fallback should be retained for standalone SPM use."
    )
}

// MARK: - Fork change 5: input_mask dispatch
//
// The two shipped models use opposite input naming and only the AI model takes a
// mask:
//   zhizi-b28 (AI)   spatial_input / global_input / input_mask
//   fp16m1 (humanSL) input_spatial / input_global / input_meta
//
// This cannot be tested through a mock. Dispatch reads
// `(model as? MLModel)?.modelDescription`, and mocks conform to ModelProtocol
// without being MLModel, so a mock ALWAYS takes the upstream branch. That is
// exactly why the existing suite stayed green while this was missing.

@Test func forkChange5_inferenceDispatchesOnModelNaming() throws {
    let source = try engineSource("KataGoInference.swift")
    #expect(
        source.contains("usesNewNaming"),
        """
        Fork change 5 missing: KataGoInference must dispatch on usesNewNaming. \
        Upstream feeds input_spatial/input_global unconditionally and has no \
        input_mask anywhere, so it cannot drive zhizi-b28 at all — the AI fails \
        to move on every board size.
        """
    )
    #expect(
        source.contains("input_mask"),
        """
        Fork change 5 missing: input_mask construction is gone. The mask is what \
        confines a 19x19 net to a smaller board; without it sub-19 play breaks.
        """
    )
    #expect(
        source.contains("spatial_input") && source.contains("global_input"),
        "Fork change 5 missing: the zhizi-b28 input names spatial_input/global_input."
    )
    #expect(
        source.contains("input_spatial") && source.contains("input_global"),
        "Upstream's human-SL input path must be retained as the other branch."
    )
}

@Test func forkChange5_extractsNewModelOutputTensors() throws {
    let source = try engineSource("KataGoInference.swift")
    #expect(
        source.contains("policy_p2_conv") && source.contains("policy_pass"),
        """
        Fork change 5 missing: zhizi-b28 emits policy_p2_conv/policy_pass, which \
        need reshaping into the [1,6,362] policy layout. Upstream's inline \
        extraction reads output_policy and cannot decode this model.
        """
    )
    #expect(
        source.contains("value_sv3_bias"),
        "Fork change 5 missing: misc value arrays are synthesised from value_sv3_bias."
    )
}

// MARK: - Fork change 6: BoardState.boardSize
//
// This one IS behaviourally testable without a model — BoardState is
// constructible on its own.

@Test func forkChange6_boardStateTracksBoardSize() throws {
    for size in [9, 13, 19] {
        let board = Board(size: size)
        let state = BoardState(board: board)
        #expect(
            state.boardSize == size,
            """
            Fork change 6 broken: BoardState.boardSize is \(state.boardSize) for a \
            \(size)x\(size) board. This is what sizes input_mask — a wrong value \
            silently corrupts sub-19 inference rather than erroring.
            """
        )
    }
}

// MARK: - Fork change 7: sub-19 genmove guards

@Test func forkChange7_genmoveUsesGreedySelection() throws {
    let source = try engineSource("GTPHandler.swift")
    #expect(
        source.contains("selectMoveGreedy(from: postOutput.policyProbs)"),
        """
        Fork change 7 missing: genmove must use greedy argmax selection. \
        Upstream samples probabilistically; the fork chose deterministic play.
        """
    )
}

@Test func forkChange7_genmovePassesOnIllegalGeneratedMove() throws {
    let source = try engineSource("GTPHandler.swift")
    #expect(
        !source.contains(#"return errorResponse("illegal move: \(move)")"#),
        """
        Fork change 7 missing: genmove must pass gracefully when the model picks \
        an occupied or off-board point instead of returning "illegal move". A \
        19x19 net does this on sub-19 boards, so returning an error stalls the game.
        """
    )
}

// MARK: - Fork change 8: AI model name
//
// Upstream hardcodes its own released net. The app bundles a different one, so
// upstream's name resolves to nothing and inference fails before it can reach
// any of the dispatch above — on every board size.
//
// Note the pre-existing testLoadExistingModel cannot catch this: it fails on
// model absence whether the name is right or wrong.

@Test func forkChange8_aiModelNameMatchesShippedModel() throws {
    let source = try engineSource("KataGoInference.swift")
    #expect(
        source.contains("KataGoModel19x19fp16-zhizi-b28"),
        """
        Fork change 8 missing: the AI model name must be \
        KataGoModel19x19fp16-zhizi-b28, the net Goban3D actually bundles. \
        Upstream's default resolves to no file and every genmove fails with \
        modelNotFound.
        """
    )
    #expect(
        !source.contains("KataGoModel19x19fp16-adam-s11165M"),
        "Fork change 8 violated: upstream's model name is back — it is not the net we ship."
    )
}

@Test func forkChange8_humanSLModelNameUnchanged() throws {
    let source = try engineSource("KataGoInference.swift")
    #expect(
        source.contains("KataGoModel19x19fp16m1"),
        "The human SL model name matches upstream and should stay as-is."
    )
}

// MARK: - Fork change 9: full error detail in GTP responses
//
// Upstream returns error.localizedDescription, which for a KataGoError prints
// the useless "The operation couldn't be completed. (KataGoError error 0.)" —
// the case name and its payload are both lost. On 2026-08-24 that turned a
// one-line diagnosis (modelNotFound: <name>) into a much longer hunt.

@Test func forkChange9_gtpErrorsCarryFullDetail() throws {
    let source = try engineSource("GTPHandler.swift")
    #expect(
        !source.contains("errorResponse(error.localizedDescription)"),
        """
        Fork change 9 missing: GTP error responses must use         String(describing: error), not error.localizedDescription. The latter         renders a KataGoError as "(KataGoError error 0.)" and discards the case         and its payload, making field diagnosis far harder.
        """
    )
    #expect(
        source.contains("String(describing: error)"),
        "Fork change 9 missing: no String(describing:) error reporting found."
    )
}

// MARK: - Fork change 10: .env files stay out of git

@Test func forkChange10_envFilesAreGitignored() throws {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.pathComponents.count > 1 && dir.lastPathComponent != "Tests" {
        dir = dir.deletingLastPathComponent()
    }
    let root = dir.deletingLastPathComponent()
    let ignore = try String(contentsOf: root.appendingPathComponent(".gitignore"), encoding: .utf8)
    #expect(
        ignore.contains(".env"),
        """
        Fork change 10 missing: .gitignore must exclude .env files. Upstream does         not ignore them, and a credential committed here would have to be removed         by rewriting history.
        """
    )
}

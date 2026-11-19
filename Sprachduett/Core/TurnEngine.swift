import Foundation

public struct SessionSnapshot: Codable, Equatable {
    public var sceneID: String
    public var cursor: Int
    public var passedIDs: [String]
    public var passPhone: Bool
    public var holder: DuettRole
    public var awaitingHandoff: Bool
    public var needsRepeat: Bool
    public var updatedAt: Date

    public init(sceneID: String, cursor: Int, passedIDs: [String], passPhone: Bool, holder: DuettRole,
                awaitingHandoff: Bool, needsRepeat: Bool, updatedAt: Date) {
        self.sceneID = sceneID
        self.cursor = cursor
        self.passedIDs = passedIDs
        self.passPhone = passPhone
        self.holder = holder
        self.awaitingHandoff = awaitingHandoff
        self.needsRepeat = needsRepeat
        self.updatedAt = updatedAt
    }
}

public enum TurnPhase: Equatable {
    case speak
    case listen
    case handoff(DuettRole)
    case done
}

public struct TurnView: Equatable {
    public let phase: TurnPhase
    /// Thai, Umschrift und Bedeutung. Beim Zuhören leer, damit niemand die Zeile des anderen abliest.
    public let line: DuettLine?
    public let showsThai: Bool

    public init(phase: TurnPhase, line: DuettLine?, showsThai: Bool) {
        self.phase = phase
        self.line = line
        self.showsThai = showsThai
    }
}

public enum TurnEngine {
    public static func currentLine(scene: DuettScene, snapshot: SessionSnapshot) -> DuettLine? {
        guard snapshot.sceneID == scene.id else { return nil }
        guard snapshot.cursor >= 0, snapshot.cursor < scene.lines.count else { return nil }
        return scene.lines[snapshot.cursor]
    }

    public static func isComplete(scene: DuettScene, snapshot: SessionSnapshot) -> Bool {
        snapshot.sceneID == scene.id && snapshot.cursor >= scene.lines.count
    }

    public static func view(scene: DuettScene, snapshot: SessionSnapshot, deviceRole: DuettRole) -> TurnView {
        guard snapshot.sceneID == scene.id else {
            return TurnView(phase: .done, line: nil, showsThai: false)
        }
        guard let line = currentLine(scene: scene, snapshot: snapshot) else {
            return TurnView(phase: .done, line: nil, showsThai: false)
        }
        if snapshot.passPhone && snapshot.awaitingHandoff {
            return TurnView(phase: .handoff(line.role), line: nil, showsThai: false)
        }
        if snapshot.passPhone && snapshot.holder != line.role {
            return TurnView(phase: .handoff(line.role), line: nil, showsThai: false)
        }
        let viewer = snapshot.passPhone ? snapshot.holder : deviceRole
        if viewer != line.role {
            return TurnView(phase: .listen, line: nil, showsThai: false)
        }
        return TurnView(phase: .speak, line: line, showsThai: true)
    }

    public static func confirm(_ snapshot: SessionSnapshot, scene: DuettScene, lineID: String, at date: Date) -> SessionSnapshot {
        guard snapshot.sceneID == scene.id, let line = currentLine(scene: scene, snapshot: snapshot) else { return snapshot }
        guard line.id == lineID else { return snapshot }
        var next = snapshot
        if !next.passedIDs.contains(line.id) {
            next.passedIDs.append(line.id)
        }
        next.cursor += 1
        next.needsRepeat = false
        next.updatedAt = date
        if next.passPhone, next.cursor < scene.lines.count {
            let upcoming = scene.lines[next.cursor]
            next.awaitingHandoff = upcoming.role != next.holder
        } else {
            next.awaitingHandoff = false
        }
        return next
    }

    public static func acceptHandoff(_ snapshot: SessionSnapshot, scene: DuettScene, at date: Date) -> SessionSnapshot {
        guard snapshot.passPhone, let line = currentLine(scene: scene, snapshot: snapshot) else { return snapshot }
        guard snapshot.awaitingHandoff || snapshot.holder != line.role else { return snapshot }
        var next = snapshot
        next.holder = line.role
        next.awaitingHandoff = false
        next.updatedAt = date
        return next
    }

    public static func requestRepeat(_ snapshot: SessionSnapshot, at date: Date) -> SessionSnapshot {
        guard snapshot.cursor >= 0 else { return snapshot }
        var next = snapshot
        next.needsRepeat = true
        next.updatedAt = date
        return next
    }

    public static func rewind(_ snapshot: SessionSnapshot, scene: DuettScene, at date: Date) -> SessionSnapshot {
        guard snapshot.sceneID == scene.id, snapshot.cursor > 0 else { return snapshot }
        var next = snapshot
        next.cursor -= 1
        if let last = next.passedIDs.last, scene.lines[next.cursor].id == last {
            next.passedIDs.removeLast()
        }
        next.holder = scene.lines[next.cursor].role
        next.awaitingHandoff = next.passPhone
        next.needsRepeat = false
        next.updatedAt = date
        return next
    }

    /// Gleicher Dialog: die längere, vorwärts passende Linie gewinnt. Sonst der neuere Stand.
    public static func merge(_ left: SessionSnapshot, _ right: SessionSnapshot) -> SessionSnapshot {
        if left.sceneID != right.sceneID || left.passedIDs == right.passedIDs {
            return left.updatedAt >= right.updatedAt ? left : right
        }
        if left.passedIDs.starts(with: right.passedIDs) { return left }
        if right.passedIDs.starts(with: left.passedIDs) { return right }
        return left.updatedAt >= right.updatedAt ? left : right
    }
}

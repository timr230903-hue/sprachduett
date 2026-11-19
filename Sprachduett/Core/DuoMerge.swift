import Foundation

public struct MemberProfile: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var gender: SpeakerGender
    public var emoji: String
    public var role: DuettRole

    public init(id: String, name: String, gender: SpeakerGender, emoji: String, role: DuettRole) {
        self.id = id
        self.name = name
        self.gender = gender
        self.emoji = emoji
        self.role = role
    }
}

public struct DuoCloudState: Codable, Equatable {
    public var duoID: String
    public var title: String
    public var members: [MemberProfile]
    public var stamps: [PracticeStamp]
    public var confirmed: [ConfirmedLine]
    public var session: SessionSnapshot?
    public var updatedAt: Date

    public init(duoID: String, title: String, members: [MemberProfile], stamps: [PracticeStamp],
                confirmed: [ConfirmedLine], session: SessionSnapshot?, updatedAt: Date) {
        self.duoID = duoID
        self.title = title
        self.members = members
        self.stamps = stamps
        self.confirmed = confirmed
        self.session = session
        self.updatedAt = updatedAt
    }

    public func member(for role: DuettRole) -> MemberProfile? {
        members.first { $0.role == role }
    }

    /// Solo: beide Rollen spricht dieselbe Person. Im Duo die zugewiesene.
    public func speakerID(for role: DuettRole) -> String {
        if let match = member(for: role) { return match.id }
        return members.first?.id ?? "local"
    }
}

public enum DuoMerge {
    public static func merge(_ local: DuoCloudState, _ remote: DuoCloudState) -> DuoCloudState {
        guard local.duoID == remote.duoID else {
            return local.updatedAt >= remote.updatedAt ? local : remote
        }
        let newer = local.updatedAt >= remote.updatedAt ? local : remote
        var members: [String: MemberProfile] = [:]
        let memberOrder = local.updatedAt >= remote.updatedAt ? [remote, local] : [local, remote]
        for state in memberOrder {
            for member in state.members {
                members[member.id] = member
            }
        }
        let stamps = Set(local.stamps).union(remote.stamps)
        let confirmed = Set(local.confirmed).union(remote.confirmed)
        let session: SessionSnapshot?
        switch (local.session, remote.session) {
        case let (left?, right?):
            session = TurnEngine.merge(left, right)
        case (nil, let right):
            session = right
        case (let left, nil):
            session = left
        }
        return DuoCloudState(
            duoID: local.duoID,
            title: newer.title,
            members: members.values.sorted { $0.id < $1.id },
            stamps: stamps.sorted { lhs, rhs in
                if lhs.day == rhs.day { return lhs.userID < rhs.userID }
                return lhs.day < rhs.day
            },
            confirmed: confirmed.sorted { lhs, rhs in
                if lhs.sceneID != rhs.sceneID { return lhs.sceneID < rhs.sceneID }
                if lhs.lineID != rhs.lineID { return lhs.lineID < rhs.lineID }
                if lhs.userID != rhs.userID { return lhs.userID < rhs.userID }
                return lhs.day < rhs.day
            },
            session: session,
            updatedAt: max(local.updatedAt, remote.updatedAt)
        )
    }
}

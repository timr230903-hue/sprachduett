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

public struct LiveClaim: Codable, Equatable {
    public var itemID: String
    public var playerID: String
    public var choiceID: String
    public var at: Date

    public init(itemID: String, playerID: String, choiceID: String, at: Date) {
        self.itemID = itemID
        self.playerID = playerID
        self.choiceID = choiceID
        self.at = at
    }
}

public struct DuoCloudState: Codable, Equatable {
    public var duoID: String
    public var title: String
    public var members: [MemberProfile]
    public var stamps: [PracticeStamp]
    public var confirmed: [ConfirmedLine]
    public var session: SessionSnapshot?
    public var liveClaim: LiveClaim?
    public var updatedAt: Date

    public init(duoID: String, title: String, members: [MemberProfile], stamps: [PracticeStamp],
                confirmed: [ConfirmedLine], session: SessionSnapshot?, updatedAt: Date, liveClaim: LiveClaim? = nil) {
        self.duoID = duoID
        self.title = title
        self.members = members
        self.stamps = stamps
        self.confirmed = confirmed
        self.session = session
        self.liveClaim = liveClaim
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case duoID, title, members, stamps, confirmed, session, liveClaim, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        duoID = try container.decode(String.self, forKey: .duoID)
        title = try container.decode(String.self, forKey: .title)
        members = try container.decode([MemberProfile].self, forKey: .members)
        stamps = try container.decode([PracticeStamp].self, forKey: .stamps)
        confirmed = try container.decode([ConfirmedLine].self, forKey: .confirmed)
        session = try container.decodeIfPresent(SessionSnapshot.self, forKey: .session)
        liveClaim = try container.decodeIfPresent(LiveClaim.self, forKey: .liveClaim)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
        let claim = Self.earlierClaim(local.liveClaim, remote.liveClaim)
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
            updatedAt: max(local.updatedAt, remote.updatedAt),
            liveClaim: claim
        )
    }

    private static func earlierClaim(_ local: LiveClaim?, _ remote: LiveClaim?) -> LiveClaim? {
        switch (local, remote) {
        case let (left?, right?) where left.itemID == right.itemID:
            return left.at <= right.at ? left : right
        case let (left?, right?):
            return left.at >= right.at ? left : right
        case (nil, let right):
            return right
        case (let left, nil):
            return left
        }
    }
}

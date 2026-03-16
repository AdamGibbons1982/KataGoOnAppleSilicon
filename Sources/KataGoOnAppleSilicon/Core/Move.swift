public struct Move {
	public let location: Point?
	public let player: Stone
	public init(location: Point?, player: Stone) {
		self.location = location
		self.player = player
	}
	public static func pass(player: Stone) -> Self {
		Self(location: nil, player: player)
	}
	public static func move(at point: Point, player: Stone) -> Self {
		Self(location: point, player: player)
	}
	public var isPass: Bool {
		location == nil
	}
}

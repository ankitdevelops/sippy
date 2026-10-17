import AppKit

enum Pose: String, CaseIterable { case walk, hi, wait }

/// One selectable buddy: a bundle of frame sequences keyed by pose,
/// described by <id>/character.json inside Resources/Characters.
struct BuddyCharacter {
    let id: String
    let name: String
    private let frames: [Pose: [NSImage]]
    private let durations: [Pose: Double]
    /// Frame index where playback should loop back to after a full pass.
    private let loopStarts: [Pose: Int]
    /// Whether leaving the screen plays the walk cycle (false = vanish).
    let animatedExit: Bool

    func frames(for pose: Pose) -> [NSImage] { frames[pose] ?? frames[.hi] ?? [] }
    func duration(for pose: Pose) -> Double { durations[pose] ?? 0.07 }
    func loopStart(for pose: Pose) -> Int { min(loopStarts[pose] ?? 0, frames(for: pose).count - 1) }

    static func loadAll() -> [BuddyCharacter] {
        guard let base = Bundle.module.resourceURL?.appendingPathComponent("Resources/Characters") else { return [] }
        let ids = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        return ids.sorted().compactMap { load(id: $0, base: base) }
    }

    static func load(id: String, base: URL? = nil) -> BuddyCharacter? {
        guard let base else { return nil }
        let dir = base.appendingPathComponent(id)
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("character.json")),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let states = obj["states"] as? [String: String] ?? [:]
        let durs = obj["frameDurations"] as? [String: Double] ?? [:]
        // Optional per-play loop point: play the sequence fully (from frame 0),
        // then keep looping only frames [loopFrom .. end].
        let loops = obj["loopFrom"] as? [String: Int] ?? [:]
        var frameMap: [Pose: [NSImage]] = [:]
        var durationMap: [Pose: Double] = [:]
        for pose in Pose.allCases {
            let folder = states[pose.rawValue] ?? pose.rawValue
            let pngs = loadFrames(in: dir.appendingPathComponent(folder))
            guard !pngs.isEmpty else { return nil } // every pose needs something
            frameMap[pose] = pngs
            durationMap[pose] = durs[pose.rawValue] ?? 0.07
        }
        let loopMap: [Pose: Int] = loops.reduce(into: [:]) { partial, entry in
            if let pose = Pose(rawValue: entry.key) { partial[pose] = max(0, entry.value) }
        }
        return BuddyCharacter(id: id,
                              name: obj["name"] as? String ?? id,
                              frames: frameMap,
                              durations: durationMap,
                              loopStarts: loopMap.mapValues { max(0, $0) },
                              animatedExit: obj["animatedExit"] as? Bool ?? true)
    }

    private static func loadFrames(in dir: URL) -> [NSImage] {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasSuffix(".png") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return names.compactMap { NSImage(contentsOf: dir.appendingPathComponent($0)) }
    }
}

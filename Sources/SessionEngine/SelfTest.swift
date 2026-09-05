import Foundation

/// Dependency-free checks for the engine's pure logic. Lives in-module so it can
/// reach internal helpers, and runs under the Command Line Tools toolchain alone
/// (no XCTest / full Xcode required). Exposed via `deck selftest`.
public enum SelfTest {
    public static func run() -> [(name: String, ok: Bool)] {
        var r: [(String, Bool)] = []

        r.append(("parseEtime SS",          Discovery.parseEtime("05") == 5))
        r.append(("parseEtime MM:SS",       Discovery.parseEtime("12:30") == 12 * 60 + 30))
        r.append(("parseEtime HH:MM:SS",    Discovery.parseEtime("01:00:00") == 3600))
        r.append(("parseEtime DD-HH:MM:SS", Discovery.parseEtime("18-16:12:53") == ((18 * 24 + 16) * 60 + 12) * 60 + 53))

        r.append(("humanUptime minutes",    Discovery.humanUptime(90) == "1m"))
        r.append(("humanUptime hours",      Discovery.humanUptime(3660) == "1h 1m"))
        r.append(("humanUptime days",       Discovery.humanUptime(172800) == "2d 0h"))

        let idle = LiveAgent(pid: 1, kind: .claude, folder: "/x",
                             uptimeSeconds: 0, uptimeText: "0m", rssMB: 12)
        let busy = LiveAgent(pid: 2, kind: .claude, folder: "/x",
                             uptimeSeconds: 0, uptimeText: "0m", rssMB: 200)
        r.append(("idle heuristic small",   idle.isLikelyIdle))
        r.append(("idle heuristic big",     !busy.isLikelyIdle))

        let spaced = LiveAgent(pid: 3, kind: .codex, folder: "/a/b/truck app",
                               uptimeSeconds: 0, uptimeText: "0m", rssMB: 1)
        r.append(("folderName with spaces", spaced.folderName == "truck app"))

        return r
    }
}

import Foundation
import SessionEngine

// deck: the CLI front-end for the Helm session engine.
//   deck            list live agents + dev servers (default)
//   deck list       same
//   deck servers    just the dev servers
//   deck sleep <pid> send SIGTERM to a live agent to reclaim its RAM
//   deck --json     machine-readable output (for the GUI to consume later)

let args = Array(CommandLine.arguments.dropFirst())
let wantJSON = args.contains("--json")
let command = args.first(where: { !$0.hasPrefix("-") }) ?? "list"

func bold(_ s: String) -> String { "\u{1B}[1m\(s)\u{1B}[0m" }
func dim(_ s: String) -> String { "\u{1B}[2m\(s)\u{1B}[0m" }
func yellow(_ s: String) -> String { "\u{1B}[33m\(s)\u{1B}[0m" }

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
}
func lpad(_ s: String, _ n: Int) -> String {
    s.count >= n ? s : String(repeating: " ", count: n - s.count) + s
}

func printAgents(_ agents: [LiveAgent]) {
    let totalMB = agents.reduce(0) { $0 + $1.rssMB }
    print(bold("LIVE AGENTS (\(agents.count))  \(totalMB) MB total"))
    if agents.isEmpty { print("  none"); return }
    for a in agents {
        let kind = pad(a.kind.rawValue, 6)
        let ram = lpad("\(a.rssMB)MB", 7)
        let up = pad(a.uptimeText, 8)
        let idle = a.isLikelyIdle ? yellow(" idle?") : "      "
        print("  \(lpad("\(a.pid)", 6))  \(kind) \(ram)  up \(up)\(idle)  \(a.folder)")
    }
}

func printServers(_ servers: [DevServer]) {
    print(bold("DEV SERVERS (\(servers.count))"))
    if servers.isEmpty { print("  none"); return }
    for s in servers {
        print("  \(pad(s.command, 6)) \(lpad(":\(s.port)", 6))  up \(pad(s.uptimeText, 8))  \(s.folder)")
    }
}

struct Snapshot: Codable {
    let agents: [LiveAgent]
    let servers: [DevServer]
}

switch command {
case "list", "ls":
    let agents = Discovery.liveAgents()
    let servers = Discovery.devServers()
    if wantJSON {
        let data = try JSONEncoder().encode(Snapshot(agents: agents, servers: servers))
        print(String(data: data, encoding: .utf8) ?? "{}")
    } else {
        printAgents(agents)
        print("")
        printServers(servers)
    }

case "servers":
    let servers = Discovery.devServers()
    if wantJSON {
        let data = try JSONEncoder().encode(servers)
        print(String(data: data, encoding: .utf8) ?? "[]")
    } else {
        printServers(servers)
    }

case "sleep":
    guard let pid = args.dropFirst().compactMap({ Int($0) }).first else {
        FileHandle.standardError.write(Data("usage: deck sleep <pid>\n".utf8))
        exit(2)
    }
    if Discovery.sleepAgent(pid: pid) {
        print("slept agent \(pid): SIGTERM sent, RAM reclaimed, session resumable from disk")
    } else {
        FileHandle.standardError.write(Data("pid \(pid) is not a live claude/codex agent\n".utf8))
        exit(1)
    }

case "selftest":
    let results = SelfTest.run()
    var failed = 0
    for r in results {
        print("  \(r.ok ? "ok  " : bold("FAIL")) \(r.name)")
        if !r.ok { failed += 1 }
    }
    print("\(results.count - failed)/\(results.count) passed")
    if failed > 0 { exit(1) }

default:
    print("""
    helm deck — session control
      deck [list]        live agents + dev servers
      deck servers       dev servers only
      deck sleep <pid>   stop a live agent, reclaim its RAM (resumable later)
      deck selftest      run the engine's built-in checks
      flags: --json
    """)
}

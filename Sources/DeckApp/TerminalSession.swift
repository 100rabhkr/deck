import Foundation
import Termini

/// Drives one PTY and its terminal surface directly (instead of the bundled
/// convenience workspace), so we can watch the output stream for the terminal
/// bell (0x07) and fire an attention signal. Wiring mirrors the library's own
/// workspace, plus the bell tap.
@MainActor
final class TerminalSession {
    let controller = TerminiTerminalController()
    private var process: TerminiLocalPTYProcess?
    private let spec: TerminiProcessSpec

    /// Fired on the main actor when the program rings the bell.
    var onBell: (() -> Void)?

    init(spec: TerminiProcessSpec) {
        self.spec = spec
        controller.onSizeChange = { [weak self] size in
            self?.process?.resize(to: .init(columns: size.columns, rows: size.rows))
        }
        controller.onInputText = { [weak self] text in
            self?.send(Data(text.utf8))
        }
        controller.onDeleteBackward = { [weak self] in
            self?.send(Data([0x7f]))
        }
        controller.onTransportWrite = { [weak self] data in
            self?.send(data)
        }
    }

    func start() {
        let p = TerminiLocalPTYProcess()
        p.onOutput = { [weak self] data in
            let bell = data.contains(0x07)
            Task { @MainActor in
                guard let self else { return }
                self.controller.processRemoteOutput(data)
                if bell { self.onBell?() }
            }
        }
        p.onExit = { _ in }
        do {
            try p.start(spec: spec, initialSize: .init(columns: 80, rows: 24))
            process = p
        } catch {
            process = nil
        }
    }

    func send(_ data: Data) { process?.send(data) }

    func stop() {
        process?.terminate()
        process = nil
    }
}

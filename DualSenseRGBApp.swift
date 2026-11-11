import SwiftUI
import GameController
import UIKit

@MainActor
final class ControllerManager: NSObject, ObservableObject {
    @Published var controllerName = "No controller detected"
    @Published var status = "Pair your DualSense in iPhone Settings → Bluetooth."
    @Published var isConnected = false
    @Published var isRainbowRunning = false
    @Published var selectedColor = Color.blue

    private var controller: GCController?
    private var rainbowTimer: Timer?
    private var hue: CGFloat = 0

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        refreshControllers()
    }

    func startDiscovery() {
        status = "Looking for paired game controllers…"
        GCController.startWirelessControllerDiscovery { }
        refreshControllers()
    }

    func refreshControllers() {
        if let found = GCController.controllers().first {
            attach(found)
        } else {
            controller = nil
            isConnected = false
            controllerName = "No controller detected"
            status = "Pair your DualSense in iPhone Settings → Bluetooth, then tap Refresh."
            stopRainbow()
        }
    }

    private func attach(_ found: GCController) {
        controller = found
        controllerName = found.vendorName ?? "Game Controller"
        isConnected = true
        if found.light == nil {
            status = "Connected, but iOS did not expose a controllable light for this controller."
        } else {
            status = "Connected. Choose a color or start Rainbow."
        }
    }

    @objc private func controllerConnected(_ notification: Notification) {
        refreshControllers()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        refreshControllers()
    }

    func setColor(_ color: Color) {
        selectedColor = color
        guard let light = controller?.light else {
            status = "No controllable controller light is available."
            return
        }
        let ui = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            status = "Couldn't read that color."
            return
        }
        light.color = GCColor(
            red: Float(red),
            green: Float(green),
            blue: Float(blue)
        )
        status = "Color command sent."
    }

    func startRainbow() {
        guard controller?.light != nil else {
            status = "Connect a controller with a supported light first."
            return
        }
        stopRainbow()
        isRainbowRunning = true
        status = "Rainbow is running. Keep this app open."
        hue = 0
        rainbowTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let light = self.controller?.light else { return }
                self.hue += 0.0035
                if self.hue >= 1 { self.hue = 0 }
                let ui = UIColor(
                    hue: self.hue,
                    saturation: 1,
                    brightness: 1,
                    alpha: 1
                )
                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0
                ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                light.color = GCColor(red: Float(r), green: Float(g), blue: Float(b))
            }
        }
    }

    func stopRainbow() {
        rainbowTimer?.invalidate()
        rainbowTimer = nil
        isRainbowRunning = false
    }
}

struct ContentView: View {
    @StateObject private var manager = ControllerManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(systemName: manager.isConnected ? "gamecontroller.fill" : "gamecontroller")
                        .font(.system(size: 48))
                        .foregroundColor(manager.isConnected ? .green : .secondary)
                    Text(manager.controllerName)
                        .font(.title2.bold())
                    Text(manager.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    manager.startDiscovery()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        manager.refreshControllers()
                    }
                } label: {
                    Label("Refresh Controller", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ColorPicker("Choose a controller color", selection: Binding(
                    get: { manager.selectedColor },
                    set: { manager.setColor($0) }
                ), supportsOpacity: false)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Button {
                    manager.isRainbowRunning ? manager.stopRainbow() : manager.startRainbow()
                } label: {
                    Label(
                        manager.isRainbowRunning ? "Stop Rainbow" : "Start Rainbow",
                        systemImage: manager.isRainbowRunning ? "stop.fill" : "rainbow"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isRainbowRunning ? .red : .purple)
                .disabled(!manager.isConnected)

                Text("Keep DualSense RGB in the foreground while the rainbow effect runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationTitle("DualSense RGB")
        }
        .onDisappear {
            manager.stopRainbow()
        }
    }
}

@main
struct DualSenseRGBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


import SwiftUI
import GameController
import UIKit

@MainActor
final class ControllerManager: NSObject, ObservableObject {
    @Published var controllerName = "No controller detected"
    @Published var status = "Pair your DualSense in iPhone Settings → Bluetooth."
    @Published var isConnected = false
    @Published var isRainbowRunning = false

    @Published var red: Double = 0
    @Published var green: Double = 122
    @Published var blue: Double = 255
    @Published var brightness: Double = 100

    private var controller: GCController?
    private var rainbowTimer: Timer?
    private var hue: CGFloat = 0

    var previewColor: Color {
        let factor = brightness / 100
        return Color(
            red: (red / 255) * factor,
            green: (green / 255) * factor,
            blue: (blue / 255) * factor
        )
    }

    var hexColor: String {
        String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue))
    }

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.refreshControllers()
        }
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
            status = "Connected, but no controllable light is available."
        } else {
            status = "Connected. Adjust your controller lighting."
            applyLightColor()
        }
    }

    @objc private func controllerConnected(_ notification: Notification) {
        refreshControllers()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        refreshControllers()
    }

    func setRed(_ value: Double) {
        red = value
        applyLightColor()
    }

    func setGreen(_ value: Double) {
        green = value
        applyLightColor()
    }

    func setBlue(_ value: Double) {
        blue = value
        applyLightColor()
    }

    func setBrightness(_ value: Double) {
        brightness = value
        applyLightColor()
    }

    private func applyLightColor() {
        guard let light = controller?.light else {
            if isConnected {
                status = "No controllable controller light is available."
            }
            return
        }

        let factor = brightness / 100

        light.color = GCColor(
            red: Float((red / 255) * factor),
            green: Float((green / 255) * factor),
            blue: Float((blue / 255) * factor)
        )

        status = "Color applied · \(hexColor) · \(Int(brightness))% brightness"
    }

    func startRainbow() {
        guard controller?.light != nil else {
            status = "Connect a controller with a supported light first."
            return
        }

        stopRainbow()
        isRainbowRunning = true
        status = "Rainbow is running."
        hue = 0

        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let light = self.controller?.light else {
                    return
                }

                self.hue += 0.0035

                if self.hue >= 1 {
                    self.hue = 0
                }

                let ui = UIColor(
                    hue: self.hue,
                    saturation: 1,
                    brightness: CGFloat(self.brightness / 100),
                    alpha: 1
                )

                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0

                ui.getRed(&r, green: &g, blue: &b, alpha: &a)

                self.red = Double(r * 255)
                self.green = Double(g * 255)
                self.blue = Double(b * 255)

                light.color = GCColor(
                    red: Float(r),
                    green: Float(g),
                    blue: Float(b)
                )
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        rainbowTimer = timer
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
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(
                            systemName: manager.isConnected
                                ? "gamecontroller.fill"
                                : "gamecontroller"
                        )
                        .font(.system(size: 48))
                        .foregroundColor(
                            manager.isConnected ? .green : .secondary
                        )

                        Text(manager.controllerName)
                            .font(.title2.bold())

                        Text(manager.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        manager.startDiscovery()
                    } label: {
                        Label(
                            "Refresh Controller",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(manager.previewColor)
                            .frame(height: 90)
                            .overlay {
                                Text(manager.hexColor)
                                    .font(.title3.monospaced().bold())
                                    .foregroundStyle(
                                        manager.brightness < 45
                                            ? .white : .black
                                    )
                            }

                        Text("Live color preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        rgbSlider(
                            title: "Red",
                            value: manager.red,
                            tint: .red
                        ) {
                            manager.setRed($0)
                        }

                        rgbSlider(
                            title: "Green",
                            value: manager.green,
                            tint: .green
                        ) {
                            manager.setGreen($0)
                        }

                        rgbSlider(
                            title: "Blue",
                            value: manager.blue,
                            tint: .blue
                        ) {
                            manager.setBlue($0)
                        }
                    }
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Brightness")

                            Spacer()

                            Text("\(Int(manager.brightness))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { manager.brightness },
                                set: { manager.setBrightness($0) }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .tint(.yellow)
                    }
                    .padding()
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )

                    Button {
                        manager.isRainbowRunning
                            ? manager.stopRainbow()
                            : manager.startRainbow()
                    } label: {
                        Label(
                            manager.isRainbowRunning
                                ? "Stop Rainbow" : "Start Rainbow",
                            systemImage: manager.isRainbowRunning
                                ? "stop.fill" : "rainbow"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.isRainbowRunning ? .red : .purple)
                    .disabled(!manager.isConnected)
                }
                .padding()
            }
            .navigationTitle("DualSense RGB")
        }
    }

    @ViewBuilder
    private func rgbSlider(
        title: String,
        value: Double,
        tint: Color,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)

                Spacer()

                Text("\(Int(value))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                in: 0...255,
                step: 1
            )
            .tint(tint)
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

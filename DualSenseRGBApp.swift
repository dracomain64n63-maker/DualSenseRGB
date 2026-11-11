
import SwiftUI
import GameController
import UIKit

@MainActor
final class ControllerManager: NSObject, ObservableObject {
    @Published var controllerName = "No controller detected"
    @Published var status = "Pair your DualSense in Settings → Bluetooth."
    @Published var isConnected = false
    @Published var isRainbowRunning = false

    @Published var red: Double = 0
    @Published var green: Double = 122
    @Published var blue: Double = 255

    @Published var brightness: Double = 100
    @Published var rainbowSpeed: Double = 50

    private var controller: GCController?
    private var rainbowTimer: Timer?
    private var hue: CGFloat = 0

    var previewColor: Color {
        Color(
            red: red / 255,
            green: green / 255,
            blue: blue / 255
        )
    }

    var hexColor: String {
        String(
            format: "#%02X%02X%02X",
            Int(red),
            Int(green),
            Int(blue)
        )
    }

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        refreshControllers()
    }

    func startDiscovery() {
        GCController.startWirelessControllerDiscovery {
            DispatchQueue.main.async {
                self.refreshControllers()
            }
        }
    }

    func refreshControllers() {
        guard let found = GCController.controllers().first else {
            controller = nil
            isConnected = false
            controllerName = "No controller detected"
            status = "Pair your DualSense in Settings → Bluetooth."
            return
        }

        attach(found)
    }

    private func attach(_ found: GCController) {
        controller = found
        controllerName = found.vendorName ?? "DualSense"
        isConnected = true

        if found.light == nil {
            status = "Controller connected, but LED control is unavailable."
        } else {
            status = "Controller connected."
            applyLightColor()
        }
    }

    @objc private func controllerConnected(_ notification: Notification) {
        refreshControllers()
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        stopRainbow()
        controller = nil
        isConnected = false
        controllerName = "No controller detected"
        status = "Controller disconnected."
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

    func setRainbowSpeed(_ value: Double) {
        rainbowSpeed = value

        if isRainbowRunning {
            startRainbow()
        }
    }

    private func applyLightColor() {
        guard let light = controller?.light else { return }

        let multiplier = Float(brightness / 100)

        light.color = GCColor(
            red: Float(red / 255) * multiplier,
            green: Float(green / 255) * multiplier,
            blue: Float(blue / 255) * multiplier
        )

        status = "Color applied: \(hexColor)"
    }

    func startRainbow() {
        stopRainbow()
        isRainbowRunning = true

        let interval = 0.06
        let speed = max(1, rainbowSpeed)

        rainbowTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                let hueStep = CGFloat(speed / 50) * 0.0035
                self.hue += hueStep

                if self.hue >= 1 {
                    self.hue = 0
                }

                let color = UIColor(
                    hue: self.hue,
                    saturation: 1,
                    brightness: self.brightness / 100,
                    alpha: 1
                )

                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0

                color.getRed(&r, green: &g, blue: &b, alpha: nil)

                self.red = Double(r * 255)
                self.green = Double(g * 255)
                self.blue = Double(b * 255)

                self.controller?.light?.color = GCColor(
                    red: Float(r),
                    green: Float(g),
                    blue: Float(b)
                )
            }
        }

        if let rainbowTimer {
            RunLoop.main.add(rainbowTimer, forMode: .common)
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
            ScrollView {
                VStack(spacing: 24) {

                    // Controller status
                    VStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.blue)

                        Text(manager.controllerName)
                            .font(.headline)

                        Text(manager.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Refresh Controller") {
                            manager.refreshControllers()
                            manager.startDiscovery()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Color preview
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(manager.previewColor)
                            .frame(height: 100)
                            .overlay {
                                Text(manager.hexColor)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(.white)
                                    .shadow(radius: 3)
                            }

                        Text("RGB Color")
                            .font(.headline)
                    }

                    // RGB selector only
                    VStack(spacing: 18) {
                        Text("RGB Color Selector")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        rgbSlider(
                            title: "Red",
                            value: manager.red,
                            color: .red
                        ) {
                            manager.setRed($0)
                        }

                        rgbSlider(
                            title: "Green",
                            value: manager.green,
                            color: .green
                        ) {
                            manager.setGreen($0)
                        }

                        rgbSlider(
                            title: "Blue",
                            value: manager.blue,
                            color: .blue
                        ) {
                            manager.setBlue($0)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Brightness is separate
                    VStack(spacing: 12) {
                        HStack {
                            Text("Brightness")
                                .font(.headline)

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
                            in: 0...100
                        )
                        .tint(.yellow)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Rainbow speed is separate
                    VStack(spacing: 12) {
                        HStack {
                            Text("Rainbow Speed")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(manager.rainbowSpeed))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { manager.rainbowSpeed },
                                set: { manager.setRainbowSpeed($0) }
                            ),
                            in: 1...100
                        )
                        .tint(.purple)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Rainbow controls
                    Button {
                        if manager.isRainbowRunning {
                            manager.stopRainbow()
                        } else {
                            manager.startRainbow()
                        }
                    } label: {
                        Label(
                            manager.isRainbowRunning
                                ? "Stop Rainbow"
                                : "Start Rainbow",
                            systemImage: manager.isRainbowRunning
                                ? "stop.fill"
                                : "rainbow"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.isRainbowRunning ? .red : .purple)
                }
                .padding()
            }
            .navigationTitle("DualSense RGB")
        }
    }

    private func rgbSlider(
        title: String,
        value: Double,
        color: Color,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)

                Spacer()

                Text("\(Int(value))")
                    .font(.subheadline.monospacedDigit())
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
            .tint(color)
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

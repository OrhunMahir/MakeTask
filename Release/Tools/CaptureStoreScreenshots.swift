// Copied temporarily into MakeTaskTests by capture-store-screenshots.sh.
// Renders production views with an isolated in-memory store and sample content.
import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import MakeTask

final class StoreScreenshotCaptureTests: XCTestCase {
    @MainActor
    func testCapture() async throws {
        let environment = try TestEnvironment()
        let originalAppearance = NSApp.appearance
        defer {
            NSApp.appearance = originalAppearance
            environment.cleanUp()
        }
        environment.settings.transparencyEnabled = false
        environment.settings.completionSound = .none
        let context = environment.container.mainContext
        func list(_ title: String, color: NoteColor, tasks: [String], done: [String]) -> TodoList {
            let list = TodoList(title: title, color: color)
            context.insert(list)
            for (index, title) in (tasks + done).enumerated() {
                let completed = index >= tasks.count
                let task = TodoTask(title: title, isCompleted: completed,
                                    completedAt: completed ? .now : nil,
                                    sortOrder: Double(index), list: list)
                context.insert(task)
            }
            return list
        }
        let today = list("Today", color: .yellow,
                         tasks: ["Plan the week ahead", "Send the project proposal", "Make time for a walk"],
                         done: ["Clear the inbox", "Morning reading"])
        let project = list("Studio project", color: .purple,
                           tasks: ["Explore a few directions", "Refine the first concept", "Share the next draft", "Prepare the final files"],
                           done: ["Collect inspiration"])
        let personal = list("Little things", color: .teal,
                            tasks: ["Book a table for Friday", "Pick up fresh flowers", "Try a new recipe"],
                            done: ["Water the plants"])
        today.tasks.first(where: { $0.title == "Send the project proposal" })?.priorityLevel = .high
        project.tasks.first(where: { $0.title == "Refine the first concept" })?.priorityLevel = .medium
        environment.settings.defaultListID = today.id
        try context.save()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MakeTaskStoreShots-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for scene in 0..<3 {
            let dark = scene == 1
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            NSApp.appearance = appearance
            environment.settings.appearance = dark ? .dark : .light
            let canvas = StoreCaptureCanvas(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
            canvas.dark = dark
            canvas.appearance = appearance
            let window = NSWindow(contentRect: canvas.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = appearance
            window.contentView = canvas
            defer { window.close() }

            func label(_ text: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, secondary: Bool = false) {
                let field = NSTextField(labelWithString: text)
                field.font = .systemFont(ofSize: size, weight: weight)
                field.textColor = secondary
                    ? (dark ? NSColor(calibratedWhite: 0.72, alpha: 1) : NSColor(calibratedWhite: 0.36, alpha: 1))
                    : (dark ? .white : NSColor(calibratedWhite: 0.12, alpha: 1))
                field.alignment = .center
                field.frame = NSRect(x: 40, y: y, width: 1200, height: size + 16)
                canvas.addSubview(field)
            }
            label("MakeTask", size: 19, weight: .semibold, y: 727)
            let headlines = ["Keep your day in view.", "A space for every project.", "A thought. A shortcut. A task."]
            let subtitles = ["Simple desktop notes for the things that matter.",
                             "Color your lists. Find your focus. Make it yours.",
                             "Open Quick Add from anywhere with a global shortcut."]
            label(headlines[scene], size: 44, weight: .bold, y: 658)
            label(subtitles[scene], size: 20, weight: .regular, y: 614, secondary: true)

            func host<V: View>(_ view: V, frame: NSRect) {
                let hosting = NSHostingView(rootView: view
                    .modelContainer(environment.container)
                    .environmentObject(environment.coordinator)
                    .environmentObject(environment.settings)
                    .environment(\.colorScheme, dark ? .dark : .light))
                hosting.sizingOptions = []
                hosting.frame = frame
                canvas.addSubview(hosting)
            }
            if scene < 2 {
                host(NoteView(list: today), frame: NSRect(x: 88, y: 155, width: 340, height: 390))
                host(NoteView(list: project), frame: NSRect(x: 470, y: 105, width: 340, height: 430))
                host(NoteView(list: personal), frame: NSRect(x: 852, y: 155, width: 340, height: 390))
            } else {
                host(NoteView(list: personal), frame: NSRect(x: 114, y: 105, width: 340, height: 380))
                host(NoteView(list: project), frame: NSRect(x: 826, y: 160, width: 340, height: 380))
                host(QuickAddView(), frame: NSRect(x: 360, y: 265, width: 560, height: 250))
            }
            label("On your Mac. No account needed.", size: 16, weight: .medium, y: 34, secondary: true)
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(500))
            canvas.layoutSubtreeIfNeeded()
            canvas.displayIfNeeded()
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2560, pixelsHigh: 1600,
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = canvas.bounds.size
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            let captured = try XCTUnwrap(bitmap.cgImage)
            let flattened = try XCTUnwrap(CGContext(data: nil, width: 2560, height: 1600,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
            flattened.setFillColor(NSColor.white.cgColor)
            flattened.fill(CGRect(x: 0, y: 0, width: 2560, height: 1600))
            flattened.draw(captured, in: CGRect(x: 0, y: 0, width: 2560, height: 1600))
            let output = NSBitmapImageRep(cgImage: try XCTUnwrap(flattened.makeImage()))
            XCTAssertFalse(output.hasAlpha)
            XCTAssertNotEqual(output.colorAt(x: 10, y: 10), output.colorAt(x: 1280, y: 800), "Capture is blank")
            let png = try XCTUnwrap(output.representation(using: .png, properties: [:]))
            try png.write(to: directory.appendingPathComponent(["01-desktop-notes.png", "02-dark-appearance.png", "03-quick-add.png"][scene]))
        }
        print("MAKETASK_STORE_SCREENSHOTS=\(directory.path)")
    }
}

private final class StoreCaptureCanvas: NSView {
    var dark = false
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let top = dark ? NSColor(srgbRed: 0.12, green: 0.14, blue: 0.21, alpha: 1)
                       : NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 1)
        let bottom = dark ? NSColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1)
                          : NSColor(srgbRed: 0.87, green: 0.91, blue: 0.92, alpha: 1)
        NSGradient(starting: bottom, ending: top)!.draw(in: bounds, angle: 90)
    }
}

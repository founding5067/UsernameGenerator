// Usage: swift scripts/make_app_icon.swift <output-dir>
// Draws the app icon (a little generator puffing letters and numbers) and writes every PNG size used by the project.
import AppKit

struct Palette {
    let bgBottom, bgTop, body, outline, wheel, hub, pipe, puff, glyph, face: NSColor
}

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(deviceRed: r, green: g, blue: b, alpha: a)
}

func palette(_ variant: String) -> Palette {
    switch variant {
    case "dark":
        return Palette(bgBottom: c(0.08, 0.14, 0.22), bgTop: c(0.08, 0.14, 0.22), body: c(0.95, 0.60, 0.20),
                       outline: c(0.65, 0.33, 0.10), wheel: c(0.18, 0.20, 0.25), hub: c(0.70, 0.74, 0.80),
                       pipe: c(0.45, 0.52, 0.62), puff: c(1, 1, 1, 0.92), glyph: c(0.10, 0.45, 0.52), face: c(0.30, 0.15, 0.05))
    case "tinted":
        return Palette(bgBottom: c(0.10, 0.10, 0.10), bgTop: c(0.10, 0.10, 0.10), body: c(0.82, 0.82, 0.82),
                       outline: c(0.45, 0.45, 0.45), wheel: c(0.30, 0.30, 0.30), hub: c(0.90, 0.90, 0.90),
                       pipe: c(0.62, 0.62, 0.62), puff: c(1, 1, 1, 0.95), glyph: c(0.25, 0.25, 0.25), face: c(0.15, 0.15, 0.15))
    default:
        return Palette(bgBottom: c(0.28, 0.72, 0.70), bgTop: c(0.28, 0.72, 0.70), body: c(1.00, 0.67, 0.20),
                       outline: c(0.78, 0.40, 0.10), wheel: c(0.22, 0.26, 0.32), hub: c(0.85, 0.88, 0.92),
                       pipe: c(0.50, 0.58, 0.68), puff: c(1, 1, 1, 0.95), glyph: c(0.10, 0.50, 0.58), face: c(0.35, 0.17, 0.06))
    }
}

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func render(px: Int, variant: String, mac: Bool) -> Data {
    let p = palette(variant)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    if mac {
        // macOS does not mask icons, so bake in the squircle with the standard margin
        cg.translateBy(x: 100, y: 100)
        cg.scaleBy(x: 824.0 / 1024, y: 824.0 / 1024)
        rounded(0, 0, 1024, 1024, 230).addClip()
    }

    p.bgBottom.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

    // Generator
    cg.saveGState()
    cg.translateBy(x: 0, y: -60)

    // exhaust pipe (behind body)
    p.pipe.setFill(); p.outline.setStroke()
    let pipe = rounded(610, 540, 80, 130, 10); pipe.fill()
    let cap = rounded(592, 655, 116, 48, 22); cap.fill()
    p.hub.withAlphaComponent(0.35).setFill()
    rounded(622, 548, 18, 110, 9).fill()

    // feet
    p.wheel.setFill()
    rounded(250, 115, 140, 90, 24).fill(); rounded(560, 115, 140, 90, 24).fill()

    // body
    let body = rounded(190, 180, 570, 380, 95)
    p.body.setFill(); body.fill()
    p.outline.setStroke(); body.lineWidth = 14; body.stroke()
    c(1, 1, 1, 0.35).setFill()
    rounded(225, 500, 500, 26, 13).fill()

    // control panel
    let panel = rounded(570, 250, 150, 200, 36)
    p.outline.withAlphaComponent(0.35).setFill(); panel.fill()
    p.hub.setFill(); circle(645, 385, 42).fill()
    p.face.setStroke()
    let needle = NSBezierPath(); needle.move(to: NSPoint(x: 645, y: 385)); needle.line(to: NSPoint(x: 668, y: 412))
    needle.lineWidth = 9; needle.lineCapStyle = .round; needle.stroke()
    for (i, x) in [610.0, 645.0, 680.0].enumerated() {
        (i == 0 ? c(0.35, 0.90, 0.45) : p.hub.withAlphaComponent(0.8)).setFill()
        circle(x, 295, 13).fill()
    }

    // face
    p.face.setFill()
    circle(305, 395, 27).fill(); circle(445, 395, 27).fill()
    c(1, 1, 1, 0.9).setFill()
    circle(314, 405, 9).fill(); circle(454, 405, 9).fill()
    c(1.0, 0.45, 0.45, 0.45).setFill()
    circle(250, 345, 24).fill(); circle(500, 345, 24).fill()
    p.face.setStroke()
    let smile = NSBezierPath()
    smile.appendArc(withCenter: NSPoint(x: 375, y: 365), radius: 42, startAngle: 205, endAngle: 335)
    smile.lineWidth = 14; smile.lineCapStyle = .round; smile.stroke()
    cg.restoreGState()

    // Letters and numbers instead of smoke
    let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 100, weight: .heavy)
        if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: 100) { return f }
        return base
    }()
    let puffs: [(String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        ("7", 685, 725, 64, 0.95, -10), ("k", 580, 815, 74, 0.88, 8),
        ("Z", 445, 890, 82, 0.78, -6), ("3", 300, 930, 64, 0.62, 12),
    ]
    for (s, x, y, r, a, rot) in puffs {
        cg.saveGState()
        p.puff.withAlphaComponent(a).setFill()
        circle(x, y, r).fill()
        circle(x - r * 0.7, y - r * 0.25, r * 0.55).fill()
        circle(x + r * 0.7, y - r * 0.2, r * 0.5).fill()
        cg.restoreGState()
        cg.saveGState()
        cg.translateBy(x: x, y: y); cg.rotate(by: rot * .pi / 180)
        let f = NSFont(descriptor: font.fontDescriptor, size: r * 1.5)!
        let str = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: p.glyph.withAlphaComponent(min(1, a + 0.1))])
        let sz = str.size()
        str.draw(at: NSPoint(x: -sz.width / 2, y: -sz.height / 2))
        cg.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
func write(_ name: String, _ data: Data) { try! data.write(to: out.appendingPathComponent(name)) }

for v in ["light", "dark", "tinted"] { write("ios-\(v).png", render(px: 1024, variant: v, mac: false)) }
for px in [16, 32, 64, 128, 256, 512, 1024] { write("mac-\(px).png", render(px: px, variant: "light", mac: true)) }
for px in [48, 64, 96, 128, 256, 512] { write("safari-\(px).png", render(px: px, variant: "light", mac: true)) }

#!/usr/bin/env swift

/// Rick Terminal App Icon Generator
/// Generates all required macOS app icon sizes from a programmatic design
///
/// Run with: swift Scripts/GenerateAppIcon.swift
/// Or make executable: chmod +x Scripts/GenerateAppIcon.swift && ./Scripts/GenerateAppIcon.swift

import Cocoa
import Foundation

// MARK: - Theme Colors

struct RickColors {
    static let backgroundDark = NSColor(red: 0x0D/255, green: 0x10/255, blue: 0x10/255, alpha: 1.0)
    static let backgroundSecondary = NSColor(red: 0x1E/255, green: 0x37/255, blue: 0x38/255, alpha: 1.0)
    static let accentGreen = NSColor(red: 0x7F/255, green: 0xFC/255, blue: 0x50/255, alpha: 1.0)
    static let accentPurple = NSColor(red: 0x7B/255, green: 0x78/255, blue: 0xAA/255, alpha: 1.0)
    static let textPrimary = NSColor.white
}

// MARK: - Icon Sizes

/// All required macOS app icon sizes
let iconSizes: [(size: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

// MARK: - Icon Drawing

/// Draws the Rick Terminal app icon at the specified size
func drawIcon(size: CGFloat, in context: CGContext) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Calculate proportions based on size
    let cornerRadius = size * 0.22 // Apple's macOS icon corner radius
    _ = size * 0.08 // padding reserved for future use

    // MARK: Background with rounded rect (macOS Big Sur+ style)

    // Outer shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.08, color: NSColor.black.withAlphaComponent(0.5).cgColor)

    // Main background shape
    let backgroundPath = CGPath(roundedRect: rect.insetBy(dx: size * 0.02, dy: size * 0.02),
                                 cornerWidth: cornerRadius,
                                 cornerHeight: cornerRadius,
                                 transform: nil)
    context.addPath(backgroundPath)
    context.setFillColor(RickColors.backgroundDark.cgColor)
    context.fillPath()
    context.restoreGState()

    // Subtle gradient overlay for depth
    context.saveGState()
    context.addPath(backgroundPath)
    context.clip()

    let gradientColors = [
        RickColors.backgroundSecondary.withAlphaComponent(0.3).cgColor,
        RickColors.backgroundDark.cgColor
    ] as CFArray

    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: gradientColors,
                                  locations: [0.0, 0.6]) {
        context.drawLinearGradient(gradient,
                                    start: CGPoint(x: size/2, y: size),
                                    end: CGPoint(x: size/2, y: 0),
                                    options: [])
    }
    context.restoreGState()

    // MARK: Purple accent border/glow

    context.saveGState()
    let borderPath = CGPath(roundedRect: rect.insetBy(dx: size * 0.03, dy: size * 0.03),
                             cornerWidth: cornerRadius * 0.95,
                             cornerHeight: cornerRadius * 0.95,
                             transform: nil)
    context.addPath(borderPath)
    context.setStrokeColor(RickColors.accentPurple.withAlphaComponent(0.6).cgColor)
    context.setLineWidth(size * 0.015)
    context.strokePath()
    context.restoreGState()

    // MARK: Terminal prompt symbol ">_"

    // Calculate text positioning
    let centerX = size / 2
    let centerY = size / 2

    // Font size proportional to icon size
    let fontSize = size * 0.42
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

    // The terminal prompt text
    let promptText = ">_"

    // Create attributed string
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: RickColors.accentGreen
    ]

    let attributedString = NSAttributedString(string: promptText, attributes: attributes)
    let textSize = attributedString.size()

    // Draw the text centered with a subtle glow
    let textRect = CGRect(
        x: centerX - textSize.width / 2 - size * 0.02, // Slight offset left for visual balance
        y: centerY - textSize.height / 2 - size * 0.03, // Slight offset up
        width: textSize.width,
        height: textSize.height
    )

    // Green glow effect behind text
    context.saveGState()
    context.setShadow(offset: .zero, blur: size * 0.06, color: RickColors.accentGreen.withAlphaComponent(0.7).cgColor)

    // Need to draw in flipped coordinates for text
    NSGraphicsContext.saveGraphicsState()
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext
    attributedString.draw(at: textRect.origin)
    NSGraphicsContext.restoreGraphicsState()

    context.restoreGState()

    // Draw text again without glow for crisp edges
    NSGraphicsContext.saveGraphicsState()
    let nsContext2 = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current = nsContext2
    attributedString.draw(at: textRect.origin)
    NSGraphicsContext.restoreGraphicsState()

    // MARK: Subtle corner highlight (top-left)

    context.saveGState()
    context.addPath(backgroundPath)
    context.clip()

    let highlightColors = [
        NSColor.white.withAlphaComponent(0.08).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray

    if let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: highlightColors,
                                   locations: [0.0, 0.5]) {
        context.drawRadialGradient(highlight,
                                    startCenter: CGPoint(x: size * 0.2, y: size * 0.8),
                                    startRadius: 0,
                                    endCenter: CGPoint(x: size * 0.2, y: size * 0.8),
                                    endRadius: size * 0.6,
                                    options: [])
    }
    context.restoreGState()
}

/// Creates an NSImage of the icon at the specified pixel dimensions
func createIconImage(pixelSize: Int) -> NSImage? {
    let size = CGFloat(pixelSize)

    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return nil
    }

    // Flip coordinate system for proper text rendering
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    drawIcon(size: size, in: context)

    image.unlockFocus()
    return image
}

/// Saves an NSImage as PNG to the specified path
func saveImage(_ image: NSImage, to path: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Error saving \(path): \(error)")
        return false
    }
}

// MARK: - Main Execution

func main() {
    // Get the script's directory to find the project root
    let scriptPath = CommandLine.arguments[0]
    let scriptURL = URL(fileURLWithPath: scriptPath)
    let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

    let outputDir = projectRoot.appendingPathComponent("RickTerminal/Assets.xcassets/AppIcon.appiconset")

    print("Rick Terminal App Icon Generator")
    print("================================")
    print("Output directory: \(outputDir.path)")
    print("")

    // Create output directory if needed
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: outputDir.path) {
        do {
            try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } catch {
            print("Error creating output directory: \(error)")
            exit(1)
        }
    }

    // Generate all icon sizes
    var successCount = 0

    for (size, scale, filename) in iconSizes {
        let pixelSize = size * scale
        let outputPath = outputDir.appendingPathComponent(filename).path

        if let image = createIconImage(pixelSize: pixelSize) {
            if saveImage(image, to: outputPath) {
                print("Generated: \(filename) (\(pixelSize)x\(pixelSize) pixels)")
                successCount += 1
            } else {
                print("FAILED: \(filename)")
            }
        } else {
            print("FAILED to create image: \(filename)")
        }
    }

    print("")
    print("Generated \(successCount)/\(iconSizes.count) icons")

    if successCount == iconSizes.count {
        print("All icons generated successfully!")
    } else {
        print("Some icons failed to generate.")
        exit(1)
    }
}

main()

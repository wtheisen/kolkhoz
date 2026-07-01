import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PixelFontSize: Int {
    case xSmall = 8
    case small = 10
    case caption2 = 11
    case caption = 13
    case headline = 17
    case title = 20
    case cardRank = 24
}

enum PixelFontVariant: String {
    case regular = "b2"
    case heavy = "b4"
}

struct PixelText: View {
    private static let opticalYOffset: CGFloat = 4

    @Environment(\.kolkhozReadability) private var readability
    let text: String
    let size: PixelFontSize
    var variant: PixelFontVariant = .regular
    var color: Color = .kolkhozCream
    var alignment: HorizontalAlignment = .leading
    var scalesWithReadability = true

    var body: some View {
        if useReadableText {
            readableText
        } else if let atlas = PixelFontAtlasCache.shared.atlas(variant: variant, size: size) {
            VStack(alignment: alignment, spacing: 0) {
                ForEach(Array(text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).enumerated()), id: \.offset) { _, line in
                    PixelTextLine(text: String(line), atlas: atlas, color: color)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(text))
            .offset(y: Self.opticalYOffset)
        } else {
            Text(text)
                .font(fallbackFont)
                .foregroundStyle(color)
                .offset(y: Self.opticalYOffset)
        }
    }

    private var useReadableText: Bool {
        readability == .clear && scalesWithReadability && size != .cardRank
    }

    private var readableText: some View {
        Text(text)
            .font(readableFont)
            .fontWeight(variant == .heavy ? .bold : .semibold)
            .foregroundStyle(color)
            .multilineTextAlignment(readableAlignment)
            .accessibilityLabel(Text(text))
    }

    private var readableAlignment: TextAlignment {
        switch alignment {
        case .center:
            .center
        case .trailing:
            .trailing
        default:
            .leading
        }
    }

    private var readableFont: Font {
        let baseSize: CGFloat
        switch size {
        case .xSmall:
            baseSize = 8
        case .small:
            baseSize = 10
        case .caption2:
            baseSize = 11
        case .caption:
            baseSize = 13
        case .headline:
            baseSize = 17
        case .title:
            baseSize = 20
        case .cardRank:
            baseSize = 24
        }
        return .custom("Handjet-Regular", fixedSize: baseSize)
    }

    private var fallbackFont: Font {
        switch size {
        case .xSmall:
            .kolkhozDisplay(size: 8)
        case .small:
            .kolkhozDisplay(size: 10)
        case .caption2:
            .kolkhozTitle(.caption2)
        case .caption:
            .kolkhozTitle(.caption)
        case .headline:
            .kolkhozTitle(.headline)
        case .title:
            .kolkhozDisplay(size: 20)
        case .cardRank:
            .kolkhozDisplay(size: 24)
        }
    }
}

private struct PixelTextLine: View {
    let text: String
    let atlas: PixelFontAtlas
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(glyphRuns) { run in
                if let image = run.glyph?.image {
                    image
                        .renderingMode(.template)
                        .foregroundStyle(color)
                        .frame(width: CGFloat(run.width) / atlas.scale, height: CGFloat(atlas.lineHeight) / atlas.scale)
                } else {
                    Color.clear
                        .frame(width: CGFloat(run.width) / atlas.scale, height: CGFloat(atlas.lineHeight) / atlas.scale)
                }
            }
        }
        .frame(height: CGFloat(atlas.lineHeight) / atlas.scale, alignment: .topLeading)
    }

    private var glyphRuns: [PixelGlyphRun] {
        text.enumerated().map { index, character in
            let key = String(character)
            if character.isWhitespace {
                return PixelGlyphRun(id: index, width: atlas.spaceAdvance, glyph: nil)
            }
            let glyph = atlas.glyphs[key] ?? atlas.glyphs["?"]
            let width = glyph?.advance ?? atlas.spaceAdvance
            return PixelGlyphRun(id: index, width: width, glyph: glyph)
        }
    }
}

private struct PixelGlyphRun: Identifiable {
    let id: Int
    let width: Int
    let glyph: PixelGlyph?
}

@MainActor
private final class PixelFontAtlasCache {
    static let shared = PixelFontAtlasCache()

    private var atlases: [String: PixelFontAtlas] = [:]

    func atlas(variant: PixelFontVariant, size: PixelFontSize) -> PixelFontAtlas? {
        let name = "handjet-\(variant.rawValue)-\(size.rawValue)px"

        if let cached = atlases[name] {
            return cached
        }

        guard let atlas = PixelFontAtlas(name: name) else {
            return nil
        }

        atlases[name] = atlas
        return atlas
    }
}

private final class PixelFontAtlas {
    let lineHeight: Int
    let scale: CGFloat
    let spaceAdvance: Int
    let glyphs: [String: PixelGlyph]

    init?(name: String) {
        guard let metadataURL = Self.resourceURL(name: name, extension: "json"),
            let imageURL = Self.resourceURL(name: name, extension: "png"),
            let data = try? Data(contentsOf: metadataURL),
            let metadata = try? JSONDecoder().decode(PixelFontMetadata.self, from: data),
            let cgImage = Self.loadCGImage(from: imageURL)
        else {
            return nil
        }

        let renderScale = CGFloat(max(1, metadata.scale ?? 1))
        var loadedGlyphs: [String: PixelGlyph] = [:]
        for (character, metric) in metadata.glyphs where character != " " {
            let rect = CGRect(x: metric.x, y: metric.y, width: metric.w, height: metric.h)
            guard let crop = cgImage.cropping(to: rect) else {
                continue
            }
            loadedGlyphs[character] = PixelGlyph(
                advance: metric.advance,
                image: Image(decorative: crop, scale: renderScale, orientation: .up)
            )
        }

        self.lineHeight = metadata.lineHeight
        self.scale = renderScale
        self.spaceAdvance = metadata.glyphs[" "]?.advance ?? max(3, metadata.size / 3)
        self.glyphs = loadedGlyphs
    }

    private static func resourceURL(name: String, extension fileExtension: String) -> URL? {
        Bundle.kolkhozAppFeatureResources.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Fonts/Bitmap"
        ) ?? Bundle.kolkhozAppFeatureResources.url(
            forResource: name,
            withExtension: fileExtension
        )
    }

    private static func loadCGImage(from url: URL) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(contentsOfFile: url.path)?.cgImage
        #elseif canImport(AppKit)
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return nil
        #endif
    }
}

private struct PixelGlyph {
    let advance: Int
    let image: Image
}

private struct PixelFontMetadata: Decodable {
    let size: Int
    let scale: Int?
    let lineHeight: Int
    let glyphs: [String: PixelGlyphMetric]
}

private struct PixelGlyphMetric: Decodable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
    let advance: Int
}

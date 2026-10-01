import CoreGraphics
import Foundation

struct TrackInfo {
    var title: String
    var artist: String
    var album: String?
    var artwork: CGImage?

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sin título" : trimmed
    }

    var displayArtist: String {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Artista desconocido" : trimmed
    }

    var displayAlbum: String? {
        guard let album else { return nil }
        let trimmed = album.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

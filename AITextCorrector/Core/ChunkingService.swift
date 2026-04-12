import Foundation

struct ChunkingService {
    let maxCharsPerRequest = 3_200
    let retryAttempts = 2
    let longTextNoticeThreshold = 7_000

    func splitTextIntoChunks(_ text: String, maxChars: Int, level: Int = 0) -> [String] {
        if text.count <= maxChars { return [text] }

        let splitters: [(String) -> [String]] = [
            { splitWithCapturedDelimiter($0, pattern: #"\n{2,}"#) },
            { splitWithCapturedDelimiter($0, pattern: #"\n"#) },
            { splitWithCapturedDelimiter($0, pattern: #"[.!?]+["')\]]*\s+"#) },
            { splitWithCapturedDelimiter($0, pattern: #"\s+"#) }
        ]

        if level >= splitters.count {
            return hardSplit(text, maxChars: maxChars)
        }

        let pieces = splitters[level](text)
        if pieces.count <= 1 {
            return splitTextIntoChunks(text, maxChars: maxChars, level: level + 1)
        }

        var nestedPieces: [String] = []
        for piece in pieces where !piece.isEmpty {
            if piece.count > maxChars {
                nestedPieces.append(contentsOf: splitTextIntoChunks(piece, maxChars: maxChars, level: level + 1))
            } else {
                nestedPieces.append(piece)
            }
        }

        return groupPiecesIntoChunks(nestedPieces, maxChars: maxChars)
    }

    func splitOuterWhitespace(_ text: String) -> (leading: String, core: String, trailing: String) {
        let leading = text.prefix { $0.isWhitespace }
        let trailing = text.reversed().prefix { $0.isWhitespace }.reversed()
        let start = text.index(text.startIndex, offsetBy: leading.count)
        let end = text.index(text.endIndex, offsetBy: -trailing.count)
        let core = start <= end ? String(text[start..<end]) : ""
        return (String(leading), core, String(trailing))
    }

    func estimateMaxTokens(for text: String, configuredMaxOutputTokens: Int) -> Int {
        let minimumTokens = min(300, configuredMaxOutputTokens)
        let estimatedTokens = Int(ceil(Double(text.count) / 3.2)) + 150
        return max(minimumTokens, min(configuredMaxOutputTokens, estimatedTokens))
    }

    private func splitWithCapturedDelimiter(_ text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty { return [text] }

        var results: [String] = []
        var currentLocation = 0
        for match in matches {
            let upperBound = match.range.location + match.range.length
            let pieceRange = NSRange(location: currentLocation, length: upperBound - currentLocation)
            results.append(nsText.substring(with: pieceRange))
            currentLocation = upperBound
        }
        if currentLocation < nsText.length {
            results.append(nsText.substring(from: currentLocation))
        }
        return results
    }

    private func groupPiecesIntoChunks(_ pieces: [String], maxChars: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""

        for piece in pieces where !piece.isEmpty {
            if currentChunk.isEmpty {
                currentChunk = piece
                continue
            }

            if currentChunk.count + piece.count <= maxChars {
                currentChunk += piece
            } else {
                chunks.append(currentChunk)
                currentChunk = piece
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    private func hardSplit(_ text: String, maxChars: Int) -> [String] {
        var result: [String] = []
        var currentIndex = text.startIndex
        while currentIndex < text.endIndex {
            let nextIndex = text.index(currentIndex, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[currentIndex..<nextIndex]))
            currentIndex = nextIndex
        }
        return result
    }
}

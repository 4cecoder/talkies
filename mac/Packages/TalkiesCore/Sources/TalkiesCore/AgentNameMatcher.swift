import Foundation

/// Text normalization shared by the agent-name matcher and the intent parser.
public enum AgentSpeechText {
    /// Lowercases, folds diacritics, drops apostrophes ("what's" → "whats"), turns other
    /// punctuation into spaces, and collapses whitespace.
    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var output = ""
        output.reserveCapacity(folded.count)
        for scalar in folded.unicodeScalars {
            if scalar == "'" || scalar == "\u{2019}" || scalar == "\u{2018}" {
                continue
            }
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
            } else {
                output.append(" ")
            }
        }
        return output.split(separator: " ").joined(separator: " ")
    }

    /// Normalized words of `text`.
    public static func words(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }

    /// Normalized text with spaces removed, used for name distance ("at last" → "atlast").
    public static func compact(_ text: String) -> String {
        normalize(text).replacingOccurrences(of: " ", with: "")
    }

    private static let numberWords: [String: Int] = [
        "one": 1, "won": 1, "two": 2, "to": 2, "too": 2, "three": 3, "four": 4, "for": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "ate": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12,
    ]

    /// Parses a spoken list number: "2", "two", or a common mishearing such as "to".
    public static func number(_ word: String) -> Int? {
        if let value = Int(word), value > 0 { return value }
        return numberWords[word]
    }
}

/// An agent and every name it answers to.
public struct AgentNameCandidate: Equatable, Sendable {
    public let id: String
    public let names: [String]

    public init(id: String, names: [String]) {
        self.id = id
        self.names = names
    }

    public init(agent: AgentRef) {
        self.init(id: agent.id, names: agent.spokenNames)
    }
}

public enum AgentNameMatch: Equatable, Sendable {
    case none
    case unique(id: String, score: Double)
    /// Two or more agents matched about equally well. Talkies asks "Which agent?" and never guesses.
    case ambiguous([String])
}

/// Matches a spoken name against agent names and aliases using normalized edit distance
/// and a phonetic key, so "at last" still finds "Atlas".
public struct AgentNameMatcher: Sendable {
    /// Minimum score for an explicitly separated address ("Atlas, …").
    public static let addressThreshold = 0.7
    /// Stricter minimums for a leading name without punctuation, which could be ordinary words.
    public static let leadingNameThreshold = 0.8
    public static let leadingNameMinimumEdit = 0.6
    /// Agents whose scores are this close to the best are reported as ambiguous.
    public static let ambiguityMargin = 0.05

    public let candidates: [AgentNameCandidate]

    public init(candidates: [AgentNameCandidate]) {
        self.candidates = candidates
    }

    /// - Parameters:
    ///   - threshold: Minimum combined score.
    ///   - minimumEditSimilarity: Minimum spelling similarity, so that a phonetic match alone
    ///     cannot turn ordinary leading words ("rocks" for "Rex") into an address.
    public func match(
        _ spoken: String,
        threshold: Double = AgentNameMatcher.addressThreshold,
        minimumEditSimilarity: Double = 0
    ) -> AgentNameMatch {
        let spokenCompact = AgentSpeechText.compact(spoken)
        guard !spokenCompact.isEmpty else { return .none }

        var scores: [(id: String, score: Double)] = []
        for candidate in candidates {
            let best = candidate.names
                .map { Self.scores(spokenCompact, AgentSpeechText.compact($0)) }
                .filter { $0.edit >= minimumEditSimilarity }
                .map { max($0.edit, $0.phonetic) }
                .max() ?? 0
            if best >= threshold {
                scores.append((candidate.id, best))
            }
        }
        guard let top = scores.max(by: { $0.score < $1.score }) else { return .none }

        let contenders: [String]
        if top.score >= 1.0 {
            contenders = scores.filter { $0.score >= 1.0 }.map(\.id)
        } else {
            contenders = scores.filter { $0.score >= top.score - Self.ambiguityMargin }.map(\.id)
        }
        if contenders.count > 1 {
            return .ambiguous(contenders)
        }
        return .unique(id: top.id, score: top.score)
    }

    /// Similarity in 0…1 between two compact (normalized, spaceless) strings.
    public static func similarity(_ a: String, _ b: String) -> Double {
        let result = scores(a, b)
        return max(result.edit, result.phonetic)
    }

    /// Spelling similarity and phonetic similarity. A phonetic match is capped below an exact
    /// spelling match, and keys shorter than two sounds earn no phonetic credit.
    static func scores(_ a: String, _ b: String) -> (edit: Double, phonetic: Double) {
        guard !a.isEmpty, !b.isEmpty else { return (0, 0) }
        if a == b { return (1, 1) }
        let edit = 1 - Double(levenshtein(Array(a), Array(b))) / Double(max(a.count, b.count))
        let keyA = phoneticKey(a), keyB = phoneticKey(b)
        var phonetic = 0.0
        if keyA.count >= 2, keyB.count >= 2 {
            phonetic = 0.92 * (1 - Double(levenshtein(Array(keyA), Array(keyB))) / Double(max(keyA.count, keyB.count)))
        }
        return (edit, phonetic)
    }

    /// A small English phonetic key in the spirit of Metaphone: it merges common spellings of the
    /// same sound, voiced and unvoiced pairs, and drops vowels after the first letter.
    public static func phoneticKey(_ text: String) -> String {
        var word = AgentSpeechText.compact(text).filter { $0.isLetter }
        guard !word.isEmpty else { return "" }

        for (prefix, replacement) in [("kn", "n"), ("gn", "n"), ("wr", "r"), ("ps", "s"), ("x", "s")] where word.hasPrefix(prefix) {
            word = replacement + word.dropFirst(prefix.count)
        }
        for (pattern, replacement) in [
            ("sch", "sk"), ("tch", "x"), ("ph", "f"), ("ck", "k"), ("sh", "x"), ("ch", "x"),
            ("th", "0"), ("wh", "w"), ("gh", "g"), ("dg", "j"), ("qu", "kw"), ("q", "k"), ("x", "ks"),
        ] {
            word = word.replacingOccurrences(of: pattern, with: replacement)
        }

        let characters = Array(word)
        var mapped: [Character] = []
        for (index, character) in characters.enumerated() {
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            switch character {
            case "c": mapped.append(next.map { "eiy".contains($0) } == true ? "s" : "k")
            case "z": mapped.append("s")
            case "d": mapped.append("t")
            case "b": mapped.append("p")
            case "g": mapped.append("k")
            case "v": mapped.append("f")
            default: mapped.append(character)
            }
        }

        var key = ""
        for (index, character) in mapped.enumerated() {
            let isVowel = "aeiouy".contains(character)
            if index == 0 {
                key.append(isVowel ? "a" : character)
                continue
            }
            if isVowel || character == "h" || character == "w" { continue }
            if key.last == character { continue }
            key.append(character)
        }
        return key
    }

    static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}

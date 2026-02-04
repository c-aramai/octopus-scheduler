import Foundation

struct PromptTemplate {
    var name: String
    var description: String
    var variables: [String]
    var body: String

    /// Substitutes known variables into the prompt body.
    func rendered() -> String {
        var result = body
        let substitutions: [String: String] = [
            "CURRENT_DATE": Self.currentDateString(),
            "WORKSPACE_PATH": ("~/ARAMAI" as NSString).expandingTildeInPath,
        ]
        for (key, value) in substitutions {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    private static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

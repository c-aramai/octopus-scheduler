import Foundation

class PromptLoader {
    /// Loads a prompt template from a markdown file with YAML-like frontmatter.
    func load(from path: String) -> PromptTemplate? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[PromptLoader] Could not read file: \(path)")
            return nil
        }

        return parse(content)
    }

    /// Parses markdown content with optional `---` frontmatter into a PromptTemplate.
    func parse(_ content: String) -> PromptTemplate {
        var name = ""
        var description = ""
        var variables: [String] = []
        var body = content

        // Check for frontmatter delimited by "---"
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            // parts[0] is empty (before first ---), parts[1] is frontmatter, rest is body
            if parts.count >= 3 {
                let frontmatter = parts[1]
                body = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)

                for line in frontmatter.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("name:") {
                        name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("description:") {
                        description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("- ") && !trimmed.hasPrefix("- {") {
                        // Variable list item
                        let varName = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                        if !varName.isEmpty {
                            variables.append(varName)
                        }
                    }
                }
            }
        }

        return PromptTemplate(name: name, description: description, variables: variables, body: body)
    }
}

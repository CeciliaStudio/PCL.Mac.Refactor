//
//  String+Arguments.swift
//  PCL.Mac
//
//  Created by yuanmu on 2026/8/9.
//

public extension String {
    /// 将一行命令行参数按空白字符拆分为参数数组。
    func splitToArguments() -> [String] {
        var arguments: [String] = []
        var current: String?
        var quote: Character?
        var escaping = false

        for character in self {
            if escaping {
                current = (current ?? "") + String(character)
                escaping = false
            } else if character == "\\", quote != "'" {
                escaping = true
                current = current ?? ""
            } else if character == quote {
                quote = nil
            } else if quote == nil, character == "\"" || character == "'" {
                quote = character
                current = current ?? ""
            } else if quote == nil, character.isWhitespace {
                if let current { arguments.append(current) }
                current = nil
            } else {
                current = (current ?? "") + String(character)
            }
        }
        if escaping { current = (current ?? "") + "\\" }
        if let current { arguments.append(current) }
        return arguments
    }
}

public extension [String] {
    /// `splitToArguments()` 的逆操作：将参数数组拼回一行字符串。
    ///
    /// 含空白字符或单引号的参数会以双引号包裹，参数中的 `\` 与 `"` 会被转义，保证拼接结果重新拆分后与原数组一致。
    func joinedToArgumentLine() -> String {
        map { argument in
            let escaped: String = argument
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            if argument.isEmpty || argument.contains(where: \.isWhitespace) || argument.contains("'") {
                return "\"\(escaped)\""
            }
            return escaped
        }
        .joined(separator: " ")
    }
}

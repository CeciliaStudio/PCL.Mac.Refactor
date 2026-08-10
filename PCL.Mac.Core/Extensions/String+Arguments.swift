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

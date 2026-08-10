//
//  CrashRules.swift
//  PCL.Mac
//
//  Created by yuanmua on 2026/8/10.
//

import Foundation

/// 一条崩溃分析规则。
public struct CrashRule {
    /// 规则命中后给出的内容。
    public struct Match {
        /// 给玩家看的解决建议，只使用玩家能看懂的说法，不出现异常类名、堆栈等术语。
        public let suggestion: String
        /// 从日志中提取的技术信息，供向他人求助时参考。
        public let details: String?

        public init(_ suggestion: String, details: String? = nil) {
            self.suggestion = suggestion
            self.details = details
        }
    }

    /// 崩溃原因描述，同时用作规则标识。它会直接展示给玩家，因此不应包含术语。
    public let cause: String
    /// 是否为兜底规则。兜底规则只在没有任何具体规则命中时才会被尝试。
    public let isFallback: Bool
    /// 匹配函数。命中时返回结果，未命中时返回 `nil`。
    public let match: (CrashContext) -> Match?

    public init(cause: String, isFallback: Bool = false, match: @escaping (CrashContext) -> Match?) {
        self.cause = cause
        self.isFallback = isFallback
        self.match = match
    }

    /// 创建一条关键字规则：任意关键字命中即返回固定建议。
    /// - Parameters:
    ///   - cause: 崩溃原因描述。
    ///   - isFallback: 是否为兜底规则。
    ///   - keywords: 关键字列表，任意一个命中即视为匹配。
    ///   - suggestion: 解决建议。
    public init(cause: String, isFallback: Bool = false, keywords: [String], suggestion: String) {
        self.init(cause: cause, isFallback: isFallback) { context in
            context.contains(anyOf: keywords) ? .init(suggestion) : nil
        }
    }
}

/// 崩溃分析规则表。
///
/// 规则按优先级从高到低排列：越靠前的规则特征越明确、结论越具体、越能告诉玩家该做什么。
/// 只能描述现象、无法给出明确操作的规则一律标记为兜底规则，它们只在没有任何具体原因时才会出现。
/// 新增规则时，只需在对应分组中插入一条 `CrashRule`；新增分组时，需将其加入 `all`。
public enum CrashRules {
    /// 全部规则，按优先级从高到低排列。
    public static let all: [CrashRule] =
        definitiveRules
        + environmentRules
        + javaRules
        + memoryRules
        + accountRules
        + modLoadingRules
        + modRuntimeRules
        + graphicsRules
        + worldRules
        + fallbackRules

    // MARK: - 确定性原因

    /// 有明确标志、不会误判的原因。
    public static let definitiveRules: [CrashRule] = [
        .init(
            cause: "你手动触发了调试崩溃",
            keywords: ["Manually triggered debug crash"],
            suggestion: "这是按下 F3 + C 手动触发的崩溃，游戏本身没有问题，直接重新启动即可。"
        )
    ]

    // MARK: - 系统环境问题

    /// 系统、文件系统与原生库层面的问题。
    public static let environmentRules: [CrashRule] = [
        .init(
            cause: "缺少一项 macOS 必需的启动参数",
            keywords: [
                "Please run the JVM with -XstartOnFirstThread",
                "NSWindow should only be instantiated on the main thread"
            ],
            suggestion: "在 macOS 上运行这个版本的 Minecraft 需要一项额外的启动参数。请打开实例设置，在“额外 JVM 参数”中加入 -XstartOnFirstThread，然后重新启动游戏。"
        ),
        .init(cause: "Java 与你的电脑架构不匹配") { context in
            guard context.contains(anyOf: [
                "mach-o file, but is an incompatible architecture",
                "no suitable image found",
                "UnsatisfiedLinkError: Failed to load a library"
            ]) else { return nil }
            var suggestion: String = "游戏需要的运行库和当前 Java 的架构对不上，请在实例设置中更换 Java。"
            if let javaRuntime = context.javaRuntime {
                suggestion += "当前用的是 \(javaRuntime.architecture) 版 Java，你的电脑是 \(Architecture.systemArchitecture()) 的。"
            }
            suggestion += "如果你玩的是 1.18 或更早的版本，它只提供 Intel（x86_64）版运行库，在 Apple 芯片的 Mac 上需要选用 Intel 版 Java；更高的版本则应该选和电脑一致的版本。"
            return .init(suggestion)
        },
        .init(
            cause: "磁盘空间不足",
            keywords: ["No space left on device", "Disk quota exceeded"],
            suggestion: "磁盘满了，游戏没法保存文件。请清理一些空间后再启动。"
        ),
        .init(
            cause: "游戏没有读写文件的权限",
            keywords: [
                "java.nio.file.AccessDeniedException",
                "Permission denied",
                "Operation not permitted",
                "Read-only file system"
            ],
            suggestion: "游戏无法读写它需要的文件。请确认游戏目录不在只读的位置（例如光盘或未解压的压缩包里），并在“系统设置 - 隐私与安全性 - 完全磁盘访问权限”中允许 PCL.Mac 访问。"
        ),
        .init(
            cause: "同时打开的文件太多",
            keywords: ["Too many open files"],
            suggestion: "游戏同时打开的文件数超出了系统限制，通常是 mod 或资源包装得太多了。请减少一些 mod 后再试。"
        ),
        .init(cause: "游戏文件缺失") { context in
            guard context.contains(anyOf: [
                "Invalid paths argument, contained no existing paths",
                "Could not find net/minecraft/client/Minecraft.class"
            ]) else { return nil }
            let suggestion: String = "游戏找不到自己的核心文件，通常是这个实例没有安装完整，或者安装之后文件夹被移动、改过名。请用“补全文件”功能修复；如果这个整合包是你自己解压出来的，请改用启动器重新安装它。"
            return .init(suggestion, details: context.firstMatch(of: #"no existing paths: \[([^,\]]+)"#).map { "缺失的文件：\($0)" })
        }
    ]

    // MARK: - Java 环境问题

    /// Java 版本、实现与启动参数层面的问题。
    public static let javaRules: [CrashRule] = [
        .init(cause: "Java 版本太低") { context in
            var requirement: String? = nil
            if context.contains("UnsupportedClassVersionError"),
               let classVersionString = context.firstMatch(of: #"class file version (\d+)"#),
               let classVersion = Int(classVersionString), classVersion > 44 {
                // class file version 与 Java 主版本号的对应关系：52 -> Java 8、61 -> Java 17、65 -> Java 21
                requirement = "Java \(classVersion - 44)"
            } else if let level = context.firstMatch(of: #"compatibility level JAVA_(\d+) could not be set"#) {
                // Mixin 会声明自己需要的 Java 兼容级别，当前 Java 过低时无法设置
                requirement = "Java \(level)"
            } else if context.contains("UnsupportedClassVersionError") {
                requirement = "更高版本的 Java"
            }
            guard let requirement else { return nil }

            var suggestion: String = "游戏或某个 mod 需要 \(requirement) 才能运行"
            if let javaRuntime = context.javaRuntime {
                suggestion += "，而现在用的是 Java \(javaRuntime.majorVersion)"
            }
            suggestion += "。请在实例设置中换成 \(requirement) 后重新启动。"
            return .init(suggestion)
        },
        .init(cause: "Java 版本太新") { context in
            var actualVersion: String? = nil
            // Mixin 在扫描 JDK 内部类时会打印 “Error loading class: ... Unsupported class file major version”
            // 级别的警告，游戏并不会因此崩溃，因此只认出现在异常链中的那一次
            if let majorVersionString = context.firstMatch(of: #"^(?:Caused by|Exception in thread)[^\n]*Unsupported class file major version (\d+)"#),
               let majorVersion = Int(majorVersionString), majorVersion > 44 {
                actualVersion = "Java \(majorVersion - 44)"
            } else if !context.contains(anyOf: [
                "ClassLoaders$AppClassLoader cannot be cast",
                "Unable to make protected final java.lang.Class java.lang.ClassLoader.defineClass",
                "java.lang.module.FindException"
            ]) {
                return nil
            }

            var suggestion: String = "当前的 Java 版本太新，游戏还不认识它。"
            if let actualVersion {
                suggestion += "检测到你正在使用 \(actualVersion)。"
            } else if let javaRuntime = context.javaRuntime {
                suggestion += "你正在使用 Java \(javaRuntime.majorVersion)。"
            }
            suggestion += "请在实例设置中换一个低一些的 Java：1.16 及更早的版本用 Java 8，1.17 到 1.20.4 用 Java 17，1.20.5 及更新的版本用 Java 21。"
            return .init(suggestion)
        },
        .init(
            cause: "Java 类型不受支持",
            keywords: ["OpenJ9"],
            suggestion: "当前这个 Java 用的是 OpenJ9，Minecraft 和很多 mod 都不支持它。请在实例设置中换成常见的 Java 发行版，例如 Azul Zulu 或 Eclipse Temurin。"
        ),
        .init(cause: "重复安装了同一个前置库") { context in
            guard context.contains("module.ResolutionException"),
                  context.contains("export package") else { return nil }
            let suggestion: String = "有两个 mod 提供了同一个前置库，游戏不知道该用哪个。这通常是因为你单独装了一份前置库（比如 MixinExtras、Kotlin for Forge），而它其实已经被别的 mod 自带了。请把单独装的那一份删掉。"
            return .init(suggestion, details: context.firstMatch(of: #"Modules ([\w\-.]+) and ([\w\-.]+) export package"#).map { "冲突的库：\($0)" })
        },
        .init(cause: "启动参数有误") { context in
            guard context.contains(anyOf: [
                "Could not create the Java Virtual Machine",
                "Unrecognized VM option",
                "Unrecognized option:",
                "Invalid maximum heap size",
                "Invalid initial heap size",
                "Error occurred during initialization of VM"
            ]) else { return nil }
            var suggestion: String = "Java 没能启动起来，通常是额外 JVM 参数写错了，或者这个参数当前的 Java 版本不支持。"
            if !context.extraJvmArguments.isEmpty {
                suggestion += "你设置的额外 JVM 参数是：\(context.extraJvmArguments.joined(separator: " "))。"
            }
            suggestion += "请在实例设置中修正它，不确定的话直接清空即可。"
            return .init(suggestion, details: context.firstMatch(of: #"Unrecognized (?:VM )?option:?\s*'?([^\n']+)"#).map { "无法识别的参数：\($0)" })
        }
    ]

    // MARK: - 内存问题

    /// 堆内存分配层面的问题。
    public static let memoryRules: [CrashRule] = [
        .init(
            cause: "材质包分辨率太高",
            keywords: ["Maybe try a lower resolution resourcepack"],
            suggestion: "游戏在加载材质时内存不够了，通常是材质包分辨率太高。请换一个分辨率低一些的材质包，或者在实例设置中把内存调大。"
        ),
        .init(cause: "内存不足") { context in
            guard context.contains(anyOf: [
                "java.lang.OutOfMemoryError",
                "Could not reserve enough space",
                "GC overhead limit exceeded",
                "Out of Memory Error",
                "insufficient memory for the Java Runtime"
            ]) else { return nil }
            return .init("游戏的内存不够用了。现在分配的是 \(context.memory) MB，请在实例设置中调大一些，或者关掉一些占内存的程序后再试。")
        }
    ]

    // MARK: - 账号与验证问题

    /// 账号登录、正版验证与玩家名层面的问题。
    ///
    /// 登录失败、会话过期在正常游玩时也会被记入游戏日志且不会导致崩溃，
    /// 因此这一类特征只在崩溃报告中匹配，避免把日志噪声误判为崩溃原因。
    public static let accountRules: [CrashRule] = [
        .init(cause: "账号登录状态已失效") { context in
            context.crashReportContains(anyOf: [
                "Invalid session",
                "Failed to verify username",
                "Authentication servers are down",
                "authentication servers are currently not reachable"
            ]).map(to: "游戏没法确认你的账号。请到账号页面重新登录一次再启动；如果你用的是第三方登录，请确认那个验证服务器现在能正常访问。")
        },
        .init(cause: "账号登录被拒绝") { context in
            context.crashReportContains(anyOf: [
                "ForbiddenOperationException",
                "InvalidCredentialsException",
                "Invalid credentials",
                "Bad login",
                "Failed to login"
            ]).map(to: "验证服务器拒绝了这个账号的登录，一般是登录信息过期了。请到账号页面重新登录一次再启动游戏。")
        },
        .init(cause: "账号没有购买正版游戏") { context in
            context.crashReportContains(anyOf: [
                "User not premium",
                "user_not_premium",
                "InsufficientPrivilegesException"
            ]).map(to: "这个账号没有购买正版 Minecraft，进不了需要正版验证的服务器。请换一个已经买了游戏的账号登录。")
        },
        .init(cause: "玩家名不合法") { context in
            context.crashReportContains(anyOf: [
                "Invalid characters in username",
                "Invalid username",
                "is not a valid username"
            ]).map(to: "这个玩家名游戏不认。玩家名只能用英文字母、数字和下划线，长度不超过 16 个字符。请到账号页面改一个再启动。")
        },
        .init(cause: "连不上第三方验证服务器") { context in
            // 验证服务器不可用会导致游戏在启动阶段失败，此时通常还没有崩溃报告，因此仍在全文中匹配。
            // 但网络异常必须紧跟在 authlib-injector 的日志之后——几乎所有使用第三方登录的日志都含
            // “authlib-injector”，而超时、连接失败也可能来自 Modrinth、Realms 等无关组件
            guard context.firstMatch(of: #"\[authlib-injector\][^\n]*\n?[^\n]*(?:UnknownHostException|Connection refused|Connect timed out|Connection timed out|SSLHandshakeException)"#) != nil else { return nil }
            return .init("连不上你设置的第三方验证服务器。请检查网络，并确认验证服务器的地址填对了、现在能正常打开。")
        }
    ]

    // MARK: - Mod 加载问题

    /// Mod 加载器在启动阶段解析、校验 mod 时出现的问题。
    public static let modLoadingRules: [CrashRule] = [
        .init(cause: "缺少前置 mod") { context in
            // FormattedException 是 Fabric 对各类错误的通用包装，不能作为依赖问题的判据
            guard context.contains(anyOf: [
                "Mod resolution failed",
                "Mod resolution encountered an incompatible mod set",
                "ModResolutionException",
                "Unmet dependency listing"
            ]) else { return nil }
            let details: [String] = context.matches(of: #"^\s*-\s+((?:Mod |Install |Replace )[^\n]*)"#, limit: 6)
            var suggestion: String = "有 mod 缺少它需要的前置 mod，或者装的版本和游戏对不上。"
            if !details.isEmpty {
                suggestion += "游戏给出的提示是：\n" + details.map { "· \($0)" }.joined(separator: "\n") + "\n"
            }
            suggestion += "请按上面的提示补装缺少的前置 mod，或者把不匹配的 mod 换成对应版本。"
            return .init(suggestion)
        },
        .init(cause: "缺少 Kotlin 等语言支持库") { context in
            guard let provider = context.firstMatch(of: #"needs language provider ([\w\-]+(?::[\w.]+)?)"#) else { return nil }
            let suggestion: String = provider.contains("kotlin")
                ? "有个 mod 是用 Kotlin 写的，需要额外安装「Kotlin for Forge」（Fabric 上叫「Fabric Language Kotlin」）才能运行。请到 CurseForge 或 Modrinth 下载对应游戏版本的这个前置 mod。"
                : "有个 mod 需要一个叫 \(provider) 的支持库才能运行，请把它一起装上。"
            return .init(suggestion, details: "需要的支持库：\(provider)")
        },
        .init(cause: "缺少前置 mod 或版本不匹配") { context in
            // 旧版 Forge 使用 Missing or unsupported mandatory dependencies + Mod ID 列表，
            // NeoForge 则在崩溃报告的 Failure message 中逐条给出 “Mod A requires B x.y.z or above”
            let isLegacyFormat: Bool = context.contains("Missing or unsupported mandatory dependencies")
            // 只认 Failure message 中的依赖描述，避免把 Fabric 日志里的 “Mod 'X' requires Y” 也算进来
            let requirements: [String] = context.matches(of: #"Failure message: (Mod [^\n]*? requires [^\n]+)"#, limit: 6)
            guard isLegacyFormat || !requirements.isEmpty else { return nil }

            var suggestion: String = "有 mod 缺少它需要的前置 mod，或者前置 mod 的版本不对。"
            let modIDs: [String] = context.matches(of: #"Mod ID: '([^']+)'"#, limit: 5)
            if !modIDs.isEmpty {
                suggestion += "缺少或版本不对的是：\(modIDs.map(readableName(ofModID:)).joined(separator: "、"))。"
            }
            if !requirements.isEmpty {
                suggestion += "\n游戏给出的提示是：\n" + requirements.map { "· \($0)" }.joined(separator: "\n")
                let currentStates: [String] = context.matches(of: #"Currently, ([^\n]+)"#, limit: 6)
                    .filter { !$0.hasPrefix("We have found") }
                if !currentStates.isEmpty {
                    suggestion += "\n当前的情况：\n" + currentStates.map { "· \($0)" }.joined(separator: "\n")
                }
            }
            if modIDs.contains(where: { ["forge", "neoforge", "minecraft", "fml", "javafml"].contains($0) }) {
                suggestion += "\n其中包含游戏本体或加载器，说明这个 mod 要求的游戏版本和当前实例不一样，请换成对应版本的 mod。"
            }
            suggestion += "\n请补装或更新对应的前置 mod 后再试。"
            // 显示名便于玩家辨认，原始 ID 便于在 mods 文件夹里找到对应文件，两者都保留
            return .init(suggestion, details: modIDs.isEmpty ? nil : "相关 mod 的 ID：\(modIDs.joined(separator: "、"))")
        },
        .init(
            cause: "同一个 mod 装了两遍",
            keywords: [
                "Duplicate mods found",
                "DuplicateModsFoundException",
                "Found duplicate mods"
            ],
            suggestion: "mods 文件夹里有同一个 mod 的多个版本。请打开 mods 文件夹，把重复的、旧版本的那个删掉。"
        ),
        .init(cause: "某个 mod 启动时出错") { context in
            guard let message = context.firstMatch(of: #"[\w\-.() ]+ encountered an error while dispatching the [\w.$]+ event"#) else { return nil }
            let modName: String = context.firstMatch(of: #"([\w\-.() ]+) encountered an error while dispatching"#) ?? "某个 mod"
            let suggestion: String = "\(modName) 在启动过程中出错了，多半是它和当前游戏版本或别的 mod 不兼容。请把它更新到对应游戏版本，或者先移除它试试。"
            var details: String = message
            if let exception = context.firstMatch(of: #"Exception message: ([^\n]+)"#), !exception.hasPrefix("<") {
                details += "\n\(exception)"
            }
            return .init(suggestion, details: details)
        },
        .init(cause: "mod 放错了地方或文件不对") { context in
            let isInvalidFabricMod: Bool = context.contains("fabric.mod.json")
                && context.contains(anyOf: ["does not contain", "Could not find", "no fabric.mod.json"])
            guard isInvalidFabricMod || context.contains(anyOf: [
                "is not a valid mod file",
                "Invalid mod file",
                "has malformed or missing mcmod.info"
            ]) else { return nil }
            return .init("mods 文件夹里有游戏认不出来的文件，最常见的原因是把 Forge 的 mod 放进了 Fabric 实例（或者反过来），也可能是下载到了源码包或整合包文件。请检查每个 mod 是不是都和这个实例的加载器对应。")
        },
        .init(cause: "mod 的配置文件损坏") { context in
            guard context.contains("com.electronwill.nightconfig"),
                  context.contains(anyOf: ["ParsingException", "ParseException"]) else { return nil }
            return .init("有个 mod 的配置文件坏了，游戏读不出来。请打开实例的 config 文件夹，把对应 mod 的配置文件删掉，游戏会自动重新生成一份默认配置。")
        },
        .init(cause: "mod 需要更新的加载器") { context in
            guard context.contains("requires mixin subsystem version") else { return nil }
            return .init(
                "有个 mod 要求的加载器版本比当前装的更高。请把 Forge / NeoForge / Fabric 加载器更新到更新的版本，或者把这个 mod 换成旧一点的版本。",
                details: mixinCulprit(in: context).map { "提出要求的是：\($0)" }
            )
        },
        .init(cause: "某个 mod 初始化失败") { context in
            guard context.contains(anyOf: [
                "Failed to create mod instance",
                "Could not execute entrypoint stage"
            ]) else { return nil }
            let modID: String? = context.firstMatch(of: #"Failed to create mod instance\. ModID: ([\w\-]+)"#)
                ?? context.firstMatch(of: #"provided by '([^']+)'"#)
            var suggestion: String = modID.map { "mod「\(readableName(ofModID: $0))」在初始化时出错了。" } ?? "有个 mod 在初始化时出错了。"
            suggestion += "请确认它需要的前置 mod 都装好了；如果还是不行，把它更新一下或先移除它。"
            return .init(suggestion, details: exceptionLine(in: context))
        },
        .init(
            cause: "游戏或 mod 的文件损坏",
            keywords: [
                "java.util.zip.ZipException",
                "zip END header not found",
                "invalid CEN header",
                "ClassFormatError",
                "Invalid or corrupt jarfile"
            ],
            suggestion: "有个文件坏了，通常是下载到一半中断造成的。请把最近下载的 mod 删掉重新下一次，或者用“补全文件”功能修复游戏。"
        ),
        .init(
            cause: "mod 装得太多了",
            keywords: ["maximum id range exceeded"],
            suggestion: "游戏里的物品和方块数量超出了上限，是 mod 装得太多导致的。请减少一些 mod 后再试。"
        ),
        .init(cause: "mod 加载时报告了问题") { context in
            // Forge / NeoForge 会把每个 mod 的加载问题记录为一条 Failure message，
            // 更具体的规则未命中时，把这些原始信息原样展示给用户
            let messages: [String] = context.matches(of: #"Failure message: ([^\n]+)"#, limit: 5)
            guard !messages.isEmpty else { return nil }
            return .init(
                "游戏在加载 mod 时报告了下面这些问题，请按提示补装、更新或移除相关的 mod：\n"
                    + messages.map { "· \($0)" }.joined(separator: "\n")
            )
        }
    ]

    // MARK: - Mod 运行时问题

    /// Mod 在字节码注入与运行阶段出现的问题。
    public static let modRuntimeRules: [CrashRule] = [
        .init(cause: "有 mod 不支持 macOS") { context in
            guard let message = context.firstMatch(of: #"[^\n]*not (?:compatible with|supported on) (?:MacOS|macOS|Mac OS)[^\n]*"#) else { return nil }
            return .init("有个 mod 明确说明了它不支持 macOS，只能在 Windows 或 Linux 上用。请把它移除后再启动。", details: message)
        },
        .init(cause: "OptiFine 和当前环境不兼容") { context in
            guard context.contains("net.optifine."),
                  context.contains(anyOf: [
                      "NoSuchMethodError",
                      "NoSuchFieldError",
                      "NoClassDefFoundError",
                      "ClassNotFoundException",
                      "AbstractMethodError"
                  ]) else { return nil }
            return .init("OptiFine 和当前的 Forge 版本或别的 mod 不兼容。请换一个和你的游戏版本、Forge 版本都对应的 OptiFine；也可以改用 Sodium 这类替代 mod。")
        },
        .init(cause: "某个 mod 修改游戏时出错") { context in
            guard context.contains(anyOf: [
                "MixinApplyError",
                "Mixin apply failed",
                "MixinTransformerError",
                "mixin.transformer.throwables"
            ]) else { return nil }
            var suggestion: String = "有个 mod 在改动游戏内容时失败了，一般是它和当前游戏版本、或者和另一个 mod 起了冲突。"
            if let culprit = mixinCulprit(in: context), let modID = modID(fromMixinCulprit: culprit) {
                suggestion += "从记录看，问题出在 mod「\(readableName(ofModID: modID))」上。"
            }
            suggestion += "请把相关的 mod 更新到对应游戏版本，或者先把最近装的 mod 移除再试。"
            var details: [String] = []
            if let culprit = mixinCulprit(in: context) { details.append("出错的位置：\(culprit)") }
            if let rootCause = rootCause(in: context) { details.append("根本原因：\(rootCause)") }
            return .init(suggestion, details: details.isEmpty ? nil : details.joined(separator: "\n"))
        },
        .init(cause: "有 mod 和当前游戏版本对不上") { context in
            guard context.contains(anyOf: [
                "Critical injection failure",
                "InvalidInjectionException",
                "could not find any targets"
            ]) else { return nil }
            var suggestion: String = "有个 mod 想改动的游戏内容不存在，通常是这个 mod 不是为当前游戏版本做的。"
            if let culprit = mixinCulprit(in: context), let modID = modID(fromMixinCulprit: culprit) {
                suggestion += "从记录看，问题出在 mod「\(readableName(ofModID: modID))」上。"
            }
            suggestion += "请把它换成和你的游戏版本对应的版本。"
            return .init(suggestion, details: mixinCulprit(in: context).map { "出错的位置：\($0)" })
        },
        .init(
            cause: "mod 之间互相循环调用",
            keywords: ["java.lang.StackOverflowError"],
            suggestion: "两个 mod 互相调用陷入了死循环。请先移除最近安装的 mod，逐个排查是哪一个引起的。"
        )
    ]

    // MARK: - 图形环境问题

    /// 窗口创建、OpenGL 与显存层面的问题。
    public static let graphicsRules: [CrashRule] = [
        .init(
            cause: "显卡不支持游戏需要的图形功能",
            keywords: [
                "GLFW_VERSION_UNAVAILABLE",
                "Requested OpenGL profile",
                "does not support OpenGL",
                "Failed to create OpenGL context"
            ],
            suggestion: "你的显卡或系统不支持游戏需要的图形功能。请先把 macOS 更新到最新版本；如果装了 Sodium、Iris 这类渲染 mod，请确认它们支持 Mac。"
        ),
        .init(
            cause: "显存不足",
            keywords: ["GL_OUT_OF_MEMORY", "1285 (Out of memory)", "GL error 1285"],
            suggestion: "显存不够用了，通常是材质包分辨率太高、渲染距离拉得太远，或者渲染类 mod 装得太多。请把材质包换成低分辨率的，并把视野距离调小一些。"
        ),
        .init(
            cause: "游戏窗口创建失败",
            keywords: [
                "GLFW error",
                "GLFW_PLATFORM_ERROR",
                "Failed to create the GLFW window",
                "Couldn't set pixel format"
            ],
            suggestion: "游戏没能创建出窗口。请先把 macOS 更新到最新版本；如果装了 Sodium、Iris 这类渲染 mod，请确认它们的版本和游戏版本对应。"
        ),
        .init(
            cause: "光影加载失败",
            keywords: [
                "Failed to load shader",
                "Failed to compile shader",
                "Failed to compile vertex shader",
                "Failed to compile fragment shader",
                "Failed to create shader",
                "ShaderCompileException",
                "Invalid shaders"
            ],
            suggestion: "光影没能加载起来。Mac 支持的图形功能比 Windows 少，很多光影在 Mac 上用不了。请换一个标明支持 Mac 的光影，或者先关掉光影再启动。"
        )
    ]

    // MARK: - 存档与游戏内容问题

    /// 存档、注册表与游戏内容层面的问题。
    public static let worldRules: [CrashRule] = [
        .init(
            cause: "存档正被另一个游戏占用",
            keywords: [
                "Failed to check session lock",
                "The save is being accessed from another location",
                "SessionLockException"
            ],
            suggestion: "这个存档正在被另一个游戏进程使用。请先把其他正在运行的游戏窗口关掉，然后再进入这个存档。"
        ),
        .init(
            cause: "上一个存档还没退出干净",
            keywords: ["Multiple servers running at once is not supported"],
            suggestion: "上一个存档还没完全退出，就又打开了新的存档。请把游戏完全关掉重新启动，之后回到主菜单时稍等几秒再进入其他存档。"
        ),
        .init(
            cause: "存档文件损坏",
            keywords: [
                "ChunkIOErrorException",
                "Exception reading chunk",
                "Failed to read chunk"
            ],
            suggestion: "存档里有一部分地图数据损坏了。如果你有备份，请用备份恢复；没有备份的话，可以用 MCA Selector 这类工具删掉损坏的区域后再进入。"
        ),
        .init(
            cause: "存档里有已被移除的 mod 内容",
            keywords: [
                "Missing registry entries",
                "could not load this save",
                "Unknown registry key",
                "Registry remapping failed"
            ],
            suggestion: "这个存档里有些方块或物品来自你已经删掉的 mod。请把那些 mod 装回去再进入存档；如果确定不要了，可以在进入时选择忽略缺失内容，但存档里对应的方块会消失。"
        ),
        .init(cause: "某个游戏内容导致了崩溃") { context in
            // 覆盖 Ticking entity/player、Rendering overlay、Exception in server tick loop、
            // mouseClicked event handler 等由具体游戏内容触发的崩溃
            guard let description = context.firstMatch(of: #"^Description: ([^\n]+)"#),
                  ["Ticking", "ticking", "Rendering", "rendering", "tick loop", "event handler"]
                      .contains(where: description.contains) else { return nil }

            let contentIDs: [String] = [
                context.firstMatch(of: #"Entity Type: ([\w:.\-]+)"#),
                context.firstMatch(of: #"Block: Block\{([^}]+)\}"#),
                context.firstMatch(of: #"Block Entity Type: ([\w:.\-]+)"#)
            ].compactMap { $0 }
            let suspect: String? = contentIDs.first.flatMap(modNamespace(of:)) ?? suspectMod(in: context)

            var suggestion: String = "游戏在处理某个具体内容时崩溃了。"
            if let suspect {
                suggestion += "从记录看，它来自 mod「\(readableName(ofModID: suspect))」。请把这个 mod 更新一下，或者先移除它再试。"
            } else {
                suggestion += "请先移除最近安装或更新的 mod，逐个排查是哪一个引起的。"
            }

            var details: [String] = ["崩溃描述：\(description)"]
            if let contentID = contentIDs.first { details.append("出错的内容：\(contentID)") }
            if let exception = exceptionLine(in: context) { details.append(exception) }
            return .init(suggestion, details: details.joined(separator: "\n"))
        },
        .init(cause: "资源包损坏或不兼容") { context in
            guard context.contains("pack.mcmeta"),
                  context.contains(anyOf: ["JsonSyntaxException", "JsonParseException", "JsonIOException", "ParsingException"]) else { return nil }
            return .init("有个资源包或数据包读不出来，可能是文件坏了，也可能是它不适用于当前游戏版本。请把最近添加的资源包和数据包移除后再试。")
        }
    ]

    // MARK: - 兜底规则

    /// 只在没有任何具体原因时才会出现的规则。
    ///
    /// 它们要么只能描述现象、无法指出具体是哪个 mod，要么依据的是概率较低的可能性，
    /// 因此不能盖过上面那些能明确告诉玩家该做什么的规则。组内同样按“能否给出行动建议”排序。
    public static let fallbackRules: [CrashRule] = {
        // 这一组内的规则全部作为兜底，统一在末尾标记，避免逐条重复书写
        let rules: [CrashRule] = [
        .init(cause: "玩家名包含中文或特殊字符") { context in
            guard !context.playerName.isEmpty,
                  context.playerName.contains(where: { !$0.isASCII }) else { return nil }
            return .init("你的玩家名「\(context.playerName)」包含中文或其他非英文字符。Minecraft 与很多 mod 只支持英文字母、数字和下划线，用其他字符可能导致存档读写失败甚至无法进入游戏。请到账号页面把玩家名改成纯英文后再试。")
        },
        .init(cause: "游戏路径包含中文或特殊字符") { context in
            guard !context.gameDirectory.isEmpty,
                  context.gameDirectory.contains(where: { !$0.isASCII }) else { return nil }
            return .init(
                "游戏所在的文件夹路径里有中文或其他特殊字符，少数 mod 无法正确处理这样的路径。如果换掉别的办法都不管用，可以试着把游戏目录移动到一个全英文的路径下。",
                details: "当前路径：\(context.gameDirectory)"
            )
        },
        .init(cause: "游戏运行环境崩溃") { context in
            guard context.hsErrLog != nil else { return nil }
            return .init(
                "运行游戏的 Java 本身崩溃了，这类问题通常和 Java 版本或显卡驱动有关。请在实例设置中换一个 Java 版本，并把 macOS 更新到最新版本后再试。",
                details: context.firstMatch(of: #"# Problematic frame:\s*\n#\s*([^\n]+)"#).map { "出错位置：\($0)" }
            )
        },
        .init(cause: "有 mod 和游戏或其他 mod 不兼容") { context in
            guard context.contains(anyOf: [
                "NoSuchMethodError",
                "NoSuchFieldError",
                "AbstractMethodError",
                "IllegalAccessError",
                "IncompatibleClassChangeError"
            ]) else { return nil }
            return .init(
                "有个 mod 用到了当前游戏里不存在的东西，一般是这个 mod 的版本和游戏版本、加载器版本或别的 mod 对不上。请回想一下最近装了或更新了哪个 mod，把它换成对应版本，或者先移除它。",
                details: context.firstMatch(of: #"(?:NoSuchMethodError|NoSuchFieldError|AbstractMethodError|IllegalAccessError|IncompatibleClassChangeError):\s*'?([^\n']+)"#).map { "找不到的内容：\($0)" }
            )
        },
        .init(cause: "缺少某个 mod 需要的前置") { context in
            guard context.contains(anyOf: ["ClassNotFoundException", "NoClassDefFoundError"]) else { return nil }
            let className: String? = context.firstMatch(of: #"(?:ClassNotFoundException|NoClassDefFoundError): ([\w./$]+)"#)
            var suggestion: String = "有个 mod 找不到它需要的东西，通常是缺少前置 mod。"
            if let namespace = className.flatMap(guessedModName(fromClassName:)) {
                suggestion += "从名字看，缺少的可能是「\(namespace)」相关的前置 mod。"
            }
            suggestion += "请确认所有 mod 需要的前置都装齐了；如果不是 mod 的问题，请用“补全文件”功能修复游戏。"
            return .init(suggestion, details: className.map { "找不到的内容：\($0)" })
        },
        .init(
            cause: "mod 加载失败",
            isFallback: true,
            keywords: [
                "EarlyLoadingException",
                "LoadingFailedException",
                "ModLoadingException",
                "Mod loading has failed",
                "ModResolutionException"
            ],
            suggestion: "游戏在加载 mod 时出错了，但没能看出具体是哪一个引起的。请先移除最近安装或更新的 mod，逐个排查；也可以点击“导出崩溃报告”把文件发给懂的人看看。"
        ),
        .init(cause: "未能识别出崩溃原因") { context in
            guard let description = context.firstMatch(of: #"^Description: ([^\n]+)"#) else { return nil }
            var suggestion: String = "PCL.Mac 没认出这次崩溃的原因。"
            if let suspect = suspectMod(in: context) {
                suggestion += "从记录看，可能和 mod「\(readableName(ofModID: suspect))」有关，可以先试着把它更新或移除。"
            } else {
                suggestion += "多数情况下是某个 mod 引起的，请先移除最近安装或更新的 mod 逐个排查。"
            }
            suggestion += "如果解决不了，请点击“导出崩溃报告”，把导出的文件发给懂的人看看。"

            var details: [String] = ["崩溃描述：\(description)"]
            if let exception = exceptionLine(in: context) { details.append(exception) }
            return .init(suggestion, details: details.joined(separator: "\n"))
        },
        .init(cause: "游戏被系统强行结束") { context in
            guard let signal = fatalSignals[context.exitCode] ?? fatalSignals[context.exitCode - 128] else { return nil }
            return .init(
                "游戏进程被系统强行结束了，通常和运行库出错或系统资源不足有关。请试着更换 Java 版本、减少 mod 数量后再启动。",
                details: "终止信号：\(signal)"
            )
        },
        .init(cause: "游戏启动时出错，未能识别出原因") { context in
            // 有崩溃报告时由上一条规则给出更准确的信息，这里只处理启动阶段失败、没有崩溃报告的情况
            guard context.crashReport == nil else { return nil }
            let topException: String? = context.firstMatch(of: #"Exception in thread "[^"]+" ([^\n]+)"#)
                ?? context.firstMatch(of: #"Uncaught exception in thread[^\n]*\n([^\n]+)"#)
                ?? context.firstMatch(of: #"^([\w.$]+(?:Exception|Error): [^\n]+)"#)
            guard let topException else { return nil }

            var details: [String] = [topException]
            if let rootCause = rootCause(in: context), rootCause != topException {
                details.append("根本原因：\(rootCause)")
            }
            return .init(
                "游戏还没进入界面就出错退出了，PCL.Mac 没认出具体原因。请先检查 Java 版本是否合适、mod 是否都对应当前游戏版本；如果解决不了，请点击“导出崩溃报告”，把导出的文件发给懂的人看看。",
                details: details.joined(separator: "\n")
            )
        },
        .init(cause: "游戏几乎没有输出任何日志") { context in
            let totalLength: Int = context.allTexts.joined().trimmingCharacters(in: .whitespacesAndNewlines).count
            guard totalLength < 256 else { return nil }
            return .init("游戏还没来得及输出任何信息就退出了，通常是 Java 没能正常启动。请在实例设置中换一个 Java 版本，并检查额外 JVM 参数是不是写错了。")
        }
        ]
        return rules.map { .init(cause: $0.cause, isFallback: true, match: $0.match) }
    }()

    // MARK: - 辅助方法

    /// 会导致进程终止的信号。`Process` 在进程被信号终止时，`terminationStatus` 可能为信号编号本身，也可能为 128 加信号编号。
    private static let fatalSignals: [Int32: String] = [
        4: "SIGILL（非法指令）",
        6: "SIGABRT（进程中止）",
        8: "SIGFPE（算术错误）",
        10: "SIGBUS（总线错误）",
        11: "SIGSEGV（段错误）"
    ]

    /// 从崩溃报告中提取紧随崩溃描述之后的异常信息行。
    /// - Parameter context: 崩溃上下文。
    /// - Returns: 异常信息行。未能提取时返回 `nil`。
    private static func exceptionLine(in context: CrashContext) -> String? {
        context.firstMatch(of: #"Description: [^\n]+\s+([\w.$]+(?:Exception|Error|Throwable)[^\n]*)"#)
    }

    /// 提取异常链最深处的根本原因。
    /// - Parameter context: 崩溃上下文。
    /// - Returns: 最后一条 `Caused by` 的内容。不存在时返回 `nil`。
    private static func rootCause(in context: CrashContext) -> String? {
        context.matches(of: #"^Caused by: ([^\n]+)"#, limit: 16).last
    }

    /// 从调用栈中推断出嫌疑 mod。
    ///
    /// Forge 与 NeoForge 的调用栈会以 `TRANSFORMER/<mod ID>@<版本>` 标注每一帧所属的 mod，
    /// 取第一个非游戏本体的 mod 作为嫌疑对象。
    /// - Parameter context: 崩溃上下文。
    /// - Returns: 嫌疑 mod 的 ID。无法推断时返回 `nil`。
    private static func suspectMod(in context: CrashContext) -> String? {
        context.matches(of: #"at TRANSFORMER/([\w\-]+)@"#, limit: 8)
            .first { !["minecraft", "forge", "neoforge", "fml"].contains($0) }
    }

    /// 定位出错的 Mixin。
    ///
    /// 崩溃报告的调用栈中会附带每一帧被哪些 Mixin 修改过的信息，直接在全文中搜索
    /// `*.mixins.json` 会抓到无关的 Mixin，因此只从 Mixin 自身的报错信息中提取。
    /// - Parameter context: 崩溃上下文。
    /// - Returns: 出错的 Mixin 描述，可能附带其所属 mod。无法定位时返回 `nil`。
    private static func mixinCulprit(in context: CrashContext) -> String? {
        let patterns: [String] = [
            #"Attach error for (\S+) from mod"#,
            #"Mixin \[([^\]]+)\]"#,
            #"in config \[([^\]]+)\]"#,
            #"Mixin config ([\w\-.]+\.json)"#,
            #"->\s+([\w\-.]+\.json):"#,
            #"Using refmap ([\w\-.]+\.json)"#
        ]
        guard let target = patterns.lazy.compactMap({ context.firstMatch(of: $0) }).first else { return nil }
        if let modID = context.firstMatch(of: #"from mod ([\w\-]+) during activity"#) {
            return "\(target)（来自 mod \(modID)）"
        }
        return target
    }

    /// 从 Mixin 定位信息中取出 mod 名，用于向玩家说明是哪个 mod 出了问题。
    /// - Parameter culprit: `mixinCulprit(in:)` 的结果。
    /// - Returns: mod 名。无法取出时返回 `nil`。
    private static func modID(fromMixinCulprit culprit: String) -> String? {
        if let modID = culprit.firstMatch(of: #"来自 mod ([\w\-]+)"#) { return modID }
        // 形如 examplemod.mixins.json 或 mixins.examplemod.json
        if let name = culprit.firstMatch(of: #"^([\w\-]+)\.mixins?\."#), name != "mixins" { return name }
        if let name = culprit.firstMatch(of: #"^mixins?\.([\w\-]+)\."#) { return name }
        return nil
    }

    /// 从缺失的类名中推断所属 mod，用于给玩家一个可读的线索。
    ///
    /// 优先查 `ModNameTable` 中人工维护的包名对照，查不到时退回按包名结构猜测。
    /// - Parameter className: 形如 `dev/tr7zw/skinlayers/...` 的类名。
    /// - Returns: 可展示给玩家的 mod 名。无法推断时返回 `nil`。
    private static func guessedModName(fromClassName className: String) -> String? {
        if let name = ModNameTable.displayName(forClassName: className) { return name }
        let segments: [String] = className.split(whereSeparator: { $0 == "/" || $0 == "." }).map(String.init)
        // 跳过 com、net、org、io 等通用前缀，取下一段作为组织或 mod 名
        guard let index = segments.firstIndex(where: { !["com", "net", "org", "io", "me", "dev", "xyz"].contains($0) }),
              index < segments.count else { return nil }
        let name: String = segments[index]
        return name == "minecraft" ? nil : name
    }

    /// 把 mod ID 换成玩家认得出的名字。
    /// - Parameter modID: mod ID。
    /// - Returns: 对照表中的显示名；表中没有时原样返回 mod ID。
    private static func readableName(ofModID modID: String) -> String {
        ModNameTable.displayName(forModID: modID) ?? modID
    }

    /// 从游戏内容 ID 中提取所属 mod 的命名空间。
    /// - Parameter id: 游戏内容 ID，如 `alexsmobs:grizzly_bear`。
    /// - Returns: mod 命名空间。属于游戏本体或无命名空间时返回 `nil`。
    private static func modNamespace(of id: String) -> String? {
        guard let namespace = id.split(separator: ":").first.map(String.init),
              namespace != id, namespace != "minecraft", !namespace.isEmpty else { return nil }
        return namespace
    }
}

private extension Bool {
    /// 条件成立时返回带该建议的匹配结果，否则返回 `nil`。
    /// - Parameter suggestion: 解决建议。
    /// - Returns: 匹配结果。
    func map(to suggestion: String) -> CrashRule.Match? {
        self ? .init(suggestion) : nil
    }
}

private extension String {
    /// 查找正则表达式的第一个匹配。
    /// - Parameter pattern: 正则表达式。
    /// - Returns: 第一个捕获组的内容。未匹配时返回 `nil`。
    func firstMatch(of pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
        let nsRange: NSRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: self) else { return nil }
        return String(self[range])
    }
}

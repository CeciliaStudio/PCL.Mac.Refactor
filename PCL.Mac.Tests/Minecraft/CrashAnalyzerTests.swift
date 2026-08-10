//
//  CrashAnalyzerTests.swift
//  PCL.Mac
//
//  Created by yuanmua on 2026/8/10.
//

import Testing
import Foundation
import Core

struct CrashAnalyzerTests {
    /// 一条崩溃样本：一段崩溃信息，以及它应当被分析出的首要原因。
    private struct Sample {
        /// 样本名称，用于定位失败的用例。
        let name: String
        /// 期望的首要原因，必须与某条规则的 `cause` 一致。
        let expectedCause: String
        /// 期望出现在建议中的片段，用于验证信息提取是否正确。
        let expectedFragments: [String]
        /// 分析所使用的上下文。
        let context: CrashContext

        init(
            _ name: String,
            cause: String,
            fragments: [String] = [],
            gameLog: String? = nil,
            crashReport: String? = nil,
            hsErrLog: String? = nil,
            exitCode: Int32 = 1,
            memory: UInt64 = 4096,
            extraJvmArguments: [String] = [],
            playerName: String = "Steve",
            gameDirectory: String = "/Users/steve/Library/Application Support/minecraft/versions/1.21.1"
        ) {
            self.name = name
            self.expectedCause = cause
            self.expectedFragments = fragments
            self.context = .init(
                gameLog: gameLog,
                crashReport: crashReport,
                hsErrLog: hsErrLog,
                exitCode: exitCode,
                memory: memory,
                extraJvmArguments: extraJvmArguments,
                playerName: playerName,
                gameDirectory: gameDirectory
            )
        }
    }

    /// 一段不应命中任何规则的正常游戏日志。
    private static let normalLog: String = """
    [12:00:00] [main/INFO]: Setting user: Steve
    [12:00:01] [Render thread/INFO]: Backend library: LWJGL version 3.3.3
    [12:00:01] [Render thread/INFO]: Reloading ResourceManager: vanilla
    [12:00:02] [Worker-Main-1/INFO]: Found unifont_all_no_pua_1.14.0.hex, loading
    [12:00:03] [Render thread/INFO]: OpenAL initialized on device Speakers
    [12:00:04] [Render thread/INFO]: Sound engine started
    [12:00:05] [Render thread/INFO]: Created: 1024x512x4 minecraft:textures/atlas/blocks.png-atlas
    """

    /// 覆盖全部规则的崩溃样本，取材自真实崩溃日志的格式。
    private static let samples: [Sample] = [
        // MARK: 确定性原因
        .init(
            "F3 + C 调试崩溃",
            cause: "你手动触发了调试崩溃",
            crashReport: "Description: Manually triggered debug crash"
        ),

        // MARK: 系统环境
        .init(
            "缺少 XstartOnFirstThread",
            cause: "缺少一项 macOS 必需的启动参数",
            gameLog: """
            Exception in thread "main" java.lang.ExceptionInInitializerError
            Caused by: java.lang.IllegalStateException: GLFW may only be initialized on the main thread and that thread must be the first thread in the process. Please run the JVM with -XstartOnFirstThread.
            """
        ),
        .init(
            "原生库架构不匹配",
            cause: "Java 与你的电脑架构不匹配",
            fragments: ["Intel"],
            gameLog: "java.lang.UnsatisfiedLinkError: /Users/steve/natives/liblwjgl.dylib: dlopen(liblwjgl.dylib, 0x0001): tried: 'liblwjgl.dylib' (mach-o file, but is an incompatible architecture (have 'x86_64', need 'arm64e' or 'arm64'))"
        ),
        .init(
            "磁盘空间不足",
            cause: "磁盘空间不足",
            gameLog: "java.io.IOException: No space left on device"
        ),
        .init(
            "文件权限不足",
            cause: "游戏没有读写文件的权限",
            gameLog: "java.nio.file.AccessDeniedException: /Users/steve/Library/Application Support/minecraft/options.txt"
        ),
        .init(
            "打开文件数超限",
            cause: "同时打开的文件太多",
            gameLog: "java.io.IOException: Too many open files"
        ),
        .init(
            "客户端 jar 缺失",
            cause: "游戏文件缺失",
            fragments: ["client-1.20.1-20230612.114412-srg.jar"],
            gameLog: "Exception in thread \"main\" java.io.UncheckedIOException: java.io.IOException: Invalid paths argument, contained no existing paths: [/Users/steve/Desktop/整合包/libraries/net/minecraft/client/1.20.1-20230612.114412/client-1.20.1-20230612.114412-srg.jar]"
        ),
        .init(
            "找不到主类",
            cause: "游戏文件缺失",
            gameLog: "Caused by: java.lang.IllegalStateException: Could not find net/minecraft/client/Minecraft.class in classloader SecureModuleClassLoader[SECURE-BOOTSTRAP]@1935972447"
        ),

        // MARK: Java 环境
        .init(
            "Java 版本过低",
            cause: "Java 版本太低",
            fragments: ["Java 21"],
            gameLog: "Exception in thread \"main\" java.lang.UnsupportedClassVersionError: net/minecraft/client/main/Main has been compiled by a more recent version of the Java Runtime (class file version 65.0), this version of the Java Runtime only recognizes class file versions up to 52.0"
        ),
        .init(
            "Mixin 要求更高的 Java",
            cause: "Java 版本太低",
            fragments: ["Java 21"],
            gameLog: "Caused by: java.lang.IllegalArgumentException: The requested compatibility level JAVA_21 could not be set. Level is not supported by the active JRE or ASM version (Java 17.0, ASM 9.10.1)"
        ),
        .init(
            "Java 版本过高",
            cause: "Java 版本太新",
            gameLog: "Exception in thread \"main\" java.lang.ClassCastException: class jdk.internal.loader.ClassLoaders$AppClassLoader cannot be cast to class java.net.URLClassLoader"
        ),
        .init(
            "类文件版本过新",
            cause: "Java 版本太新",
            fragments: ["Java 25"],
            gameLog: "Caused by: java.lang.IllegalArgumentException: Unsupported class file major version 69"
        ),
        .init(
            "重复的库 mod",
            cause: "重复安装了同一个前置库",
            fragments: ["MixinExtras"],
            gameLog: "Exception in thread \"main\" java.lang.module.ResolutionException: Modules MixinExtras and mixinextras.neoforge export package com.llamalad7.mixinextras.lib.apache.commons.builder to module javax.inject"
        ),
        .init(
            "OpenJ9 虚拟机",
            cause: "Java 类型不受支持",
            gameLog: "# JRE version: OpenJDK Runtime Environment (11.0.20) Eclipse OpenJ9 VM"
        ),
        .init(
            "JVM 参数错误",
            cause: "启动参数有误",
            fragments: ["UseZGCX", "-XX:+UseZGCX"],
            gameLog: """
            Unrecognized VM option 'UseZGCX'
            Error: Could not create the Java Virtual Machine.
            """,
            extraJvmArguments: ["-XX:+UseZGCX"]
        ),

        // MARK: 内存
        .init(
            "材质包分辨率过高",
            cause: "材质包分辨率太高",
            gameLog: """
            java.lang.OutOfMemoryError: Java heap space
            Maybe try a lower resolution resourcepack?
            """
        ),
        .init(
            "堆内存不足",
            cause: "内存不足",
            fragments: ["2048"],
            gameLog: "java.lang.OutOfMemoryError: Java heap space",
            memory: 2048
        ),

        // MARK: 账号与验证
        .init(
            "会话失效",
            cause: "账号登录状态已失效",
            crashReport: "Description: Unexpected error\n\ncom.mojang.authlib.exceptions.AuthenticationException: Invalid session (Try restarting your game)"
        ),
        .init(
            "令牌被拒绝",
            cause: "账号登录被拒绝",
            crashReport: "Description: Unexpected error\n\ncom.mojang.authlib.exceptions.ForbiddenOperationException: Invalid token"
        ),
        .init(
            "未购买正版",
            cause: "账号没有购买正版游戏",
            crashReport: "Description: Unexpected error\n\ncom.mojang.authlib.exceptions.AuthenticationException: User not premium"
        ),
        .init(
            "玩家名非法",
            cause: "玩家名不合法",
            crashReport: "Description: Unexpected error\n\njava.lang.IllegalArgumentException: Invalid characters in username"
        ),
        .init(
            "游戏日志中的登录噪声不应被误判",
            cause: "某个 mod 修改游戏时出错",
            gameLog: """
            [13:16:30] [Render thread/ERROR]: com.mojang.authlib.exceptions.InvalidCredentialsException: Status: 401
            [13:16:41] [Render thread/ERROR]: Empty response from Mojang API.
            """,
            crashReport: """
            Description: Unexpected error

            org.spongepowered.asm.mixin.transformer.throwables.MixinTransformerError: An unexpected critical error was encountered
            \tat MC-BOOTSTRAP/org.spongepowered.mixin/org.spongepowered.asm.mixin.transformer.MixinProcessor.applyMixins(MixinProcessor.java:392)
            """
        ),
        .init(
            "验证服务器不可达",
            cause: "连不上第三方验证服务器",
            gameLog: """
            [authlib-injector] [ERROR] Failed to fetch metadata from https://example.com/api/yggdrasil
            java.net.UnknownHostException: example.com
            """
        ),

        // MARK: Mod 加载
        .init(
            "Fabric 依赖缺失",
            cause: "缺少前置 mod",
            fragments: ["Install fabric-api, any version.", "requires any version of fabric-api"],
            gameLog: """
            net.fabricmc.loader.impl.FormattedException: Mod resolution encountered an incompatible mod set!
            A potential solution has been determined:
            \t - Install fabric-api, any version.
            Unmet dependency listing:
            \t - Mod 'Sodium' (sodium) 0.5.8 requires any version of fabric-api, which is missing!
            """
        ),
        .init(
            "缺少 Kotlin 语言支持库",
            cause: "缺少 Kotlin 等语言支持库",
            fragments: ["kotlinforforge:5", "Kotlin"],
            crashReport: """
            Description: Mod loading failures have occurred; consult the issue messages for more details

            -- Mod loading issue --
            Details:
            \tFailure message: Mod File mods/sliceanddice-neoforge-4.3.2.jar needs language provider kotlinforforge:5 or above to load
            """
        ),
        .init(
            "NeoForge 依赖缺失",
            cause: "缺少前置 mod 或版本不匹配",
            fragments: ["requires corpse 1.1.2 or above", "corpse is not installed"],
            crashReport: """
            Description: Mod loading failures have occurred; consult the issue messages for more details

            -- Mod loading issue --
            Details:
            \tFailure message: Mod cosmeticcorpsecompat requires corpse 1.1.2 or above
            \t\tCurrently, corpse is not installed
            """
        ),
        .init(
            "旧版 Forge 依赖缺失",
            cause: "缺少前置 mod 或版本不匹配",
            fragments: ["GeckoLib", "geckolib3"],
            crashReport: """
            Description: Mod loading failure
            net.minecraftforge.fml.ModLoadingException: Missing or unsupported mandatory dependencies:
            \tMod ID: 'geckolib3', Requested by: 'alexsmobs', Expected range: '[3.0.0,)', Actual version: '[MISSING]'
            """
        ),
        .init(
            "前置为加载器本身",
            cause: "缺少前置 mod 或版本不匹配",
            fragments: ["游戏本体或加载器"],
            crashReport: """
            Description: Mod loading failure
            Missing or unsupported mandatory dependencies:
            \tMod ID: 'forge', Requested by: 'examplemod', Expected range: '[47.2.0,)', Actual version: '47.1.3'
            """
        ),
        .init(
            "重复 mod",
            cause: "同一个 mod 装了两遍",
            gameLog: "net.minecraftforge.fml.loading.EarlyLoadingException: Duplicate mods found"
        ),
        .init(
            "mod 事件处理出错",
            cause: "某个 mod 启动时出错",
            fragments: ["Corpse (corpse) encountered an error", "ClassNotFoundException: lain.mods.cos.api.CosArmorAPI"],
            crashReport: """
            Description: Mod loading failures have occurred; consult the issue messages for more details

            -- Mod loading issue --
            Details:
            \tFailure message: Corpse (corpse) encountered an error while dispatching the net.neoforged.neoforge.registries.RegisterEvent event
            \tException message: java.lang.ClassNotFoundException: lain.mods.cos.api.CosArmorAPI
            """
        ),
        .init(
            "mod 放错加载器",
            cause: "mod 放错了地方或文件不对",
            gameLog: "Mod file examplemod-1.0.0.jar does not contain a fabric.mod.json"
        ),
        .init(
            "mod 配置损坏",
            cause: "mod 的配置文件损坏",
            gameLog: "Caused by: com.electronwill.nightconfig.core.io.ParsingException: Not enough data available"
        ),
        .init(
            "Mixin 子系统过低",
            cause: "mod 需要更新的加载器",
            fragments: ["examplemod.mixins.json"],
            gameLog: "Mixin config examplemod.mixins.json requires mixin subsystem version 0.8.5 but 0.8.4 was found"
        ),
        .init(
            "mod 初始化失败",
            cause: "某个 mod 初始化失败",
            fragments: ["examplemod"],
            gameLog: "net.minecraftforge.fml.ModLoadingException: Failed to create mod instance. ModID: examplemod, class com.example.ExampleMod"
        ),
        .init(
            "Fabric 入口点失败",
            cause: "某个 mod 初始化失败",
            fragments: ["examplemod"],
            gameLog: "net.fabricmc.loader.impl.FormattedException: Could not execute entrypoint stage 'main' due to errors, provided by 'examplemod'!"
        ),
        .init(
            "mod 文件损坏",
            cause: "游戏或 mod 的文件损坏",
            gameLog: "Caused by: java.util.zip.ZipException: zip END header not found"
        ),
        .init(
            "ID 超限",
            cause: "mod 装得太多了",
            gameLog: "java.lang.RuntimeException: maximum id range exceeded"
        ),
        .init(
            "未分类的加载问题",
            cause: "mod 加载时报告了问题",
            fragments: ["examplemod (Example Mod) 加载时出现了问题"],
            crashReport: """
            Description: Mod loading failures have occurred; consult the issue messages for more details

            -- Mod loading issue --
            Details:
            \tFailure message: examplemod (Example Mod) 加载时出现了问题
            """
        ),

        // MARK: Mod 运行时
        .init(
            "mod 声明不支持 macOS",
            cause: "有 mod 不支持 macOS",
            fragments: ["This mod is not compatible with MacOS"],
            gameLog: "[20:06:13] [Render thread/ERROR]: This mod is not compatible with MacOS. Please use Windows or Linux (wayland)."
        ),
        .init(
            "OptiFine 不兼容",
            cause: "OptiFine 和当前环境不兼容",
            gameLog: """
            java.lang.NoSuchMethodError: net.minecraft.client.renderer.texture.TextureAtlasSprite.getFrameCount()
            \tat net.optifine.SmartAnimations.spriteRendered(SmartAnimations.java:85)
            """
        ),
        .init(
            "Mixin 注入失败",
            cause: "某个 mod 修改游戏时出错",
            fragments: ["mixins.iris.compat.sodium.json:MixinRenderSectionManager（来自 mod iris）", "SodiumGameOptions$PerformanceSettings"],
            crashReport: """
            Description: Unexpected error

            org.spongepowered.asm.mixin.transformer.throwables.MixinTransformerError: An unexpected critical error was encountered
            \tat TRANSFORMER/sodium@0.8.12/net.caffeinemc.mods.sodium.client.render.SodiumWorldRenderer.initRenderer(SodiumWorldRenderer.java:303) {pl:mixin:APP:iris-batched-entity-rendering.mixins.json:MixinLevelRenderer from mod iris,pl:mixin:APP:supplementaries.mixins.json:LevelRendererMixin from mod supplementaries}
            Caused by: org.spongepowered.asm.mixin.transformer.throwables.MixinPreProcessorException: Attach error for mixins.iris.compat.sodium.json:MixinRenderSectionManager from mod iris during activity: [Transform]
            Caused by: java.lang.ClassNotFoundException: net.caffeinemc.mods.sodium.client.gui.SodiumGameOptions$PerformanceSettings
            """
        ),
        .init(
            "Mixin 目标缺失",
            cause: "有 mod 和当前游戏版本对不上",
            fragments: ["examplemod.mixins.json"],
            gameLog: "org.spongepowered.asm.mixin.injection.throwables.InvalidInjectionException: Critical injection failure: @Inject annotation on onTick could not find any targets matching 'tick' in net/minecraft/client/Minecraft. [PREINJECT Applicator Phase -> examplemod.mixins.json:ClientMixin -> Prepare Injections]"
        ),
        .init(
            "调用栈溢出",
            cause: "mod 之间互相循环调用",
            gameLog: "Caused by: java.lang.StackOverflowError"
        ),

        // MARK: 图形环境
        .init(
            "OpenGL 版本不支持",
            cause: "显卡不支持游戏需要的图形功能",
            gameLog: "[LWJGL] GLFW_VERSION_UNAVAILABLE error\nNSGL: The targeted version of macOS does not support OpenGL 4.1"
        ),
        .init(
            "显存不足",
            cause: "显存不足",
            gameLog: "[Render thread/ERROR]: OpenGL Error: 1285 (Out of memory)"
        ),
        .init(
            "窗口创建失败",
            cause: "游戏窗口创建失败",
            gameLog: "[LWJGL] GLFW_PLATFORM_ERROR error\nCocoa: Failed to retrieve display name"
        ),
        .init(
            "光影编译失败",
            cause: "光影加载失败",
            gameLog: "net.irisshaders.iris.gl.shader.ShaderCompileException: Failed to compile shader"
        ),

        // MARK: 存档与游戏内容
        .init(
            "存档被占用",
            cause: "存档正被另一个游戏占用",
            gameLog: "java.lang.IllegalStateException: Failed to check session lock, aborting"
        ),
        .init(
            "多个存档同时运行",
            cause: "上一个存档还没退出干净",
            crashReport: """
            Description: Exception in server tick loop

            java.lang.IllegalStateException: Multiple servers running at once is not supported!
            \tat TRANSFORMER/xaerolib@1.7.1/xaero.lib.common.config.server.ServerConfigManager.setServer(ServerConfigManager.java:68)
            """
        ),
        .init(
            "区块损坏",
            cause: "存档文件损坏",
            gameLog: "net.minecraft.world.chunk.storage.ChunkIOErrorException"
        ),
        .init(
            "注册表条目缺失",
            cause: "存档里有已被移除的 mod 内容",
            crashReport: "Description: Exception in server tick loop\nMissing registry entries for world"
        ),
        .init(
            "实体 tick 崩溃",
            cause: "某个游戏内容导致了崩溃",
            fragments: ["alexsmobs", "java.lang.NullPointerException"],
            crashReport: """
            Description: Ticking entity

            java.lang.NullPointerException: Cannot invoke "net.minecraft.world.level.Level.getBlockState()" because "level" is null

            -- Entity being ticked --
            Details:
            \tEntity Type: alexsmobs:grizzly_bear (com.github.alexthe666.alexsmobs.entity.EntityGrizzlyBear)
            """
        ),
        .init(
            "资源包损坏",
            cause: "资源包损坏或不兼容",
            gameLog: "com.google.gson.JsonSyntaxException: Expected BEGIN_OBJECT but was STRING while reading pack.mcmeta"
        ),

        // MARK: 兜底
        .init(
            "中文玩家名",
            cause: "玩家名包含中文或特殊字符",
            fragments: ["小明", "纯英文"],
            gameLog: "[12:00:00] [main/INFO]: Setting user: 小明\njava.lang.RuntimeException: 无法识别的错误，日志里没有更多线索可以参考的内容",
            playerName: "小明"
        ),
        .init(
            "中文游戏路径",
            cause: "游戏路径包含中文或特殊字符",
            fragments: ["未命名文件夹"],
            gameLog: "java.lang.IllegalStateException: 出了点问题，但日志里没有任何可以用来判断原因的线索内容",
            playerName: "Steve",
            gameDirectory: "/Users/steve/Desktop/未命名文件夹/整合包"
        ),
        .init(
            "JVM 致命错误",
            cause: "游戏运行环境崩溃",
            fragments: ["libglfw.dylib"],
            hsErrLog: """
            #
            # A fatal error has been detected by the Java Runtime Environment:
            #
            #  SIGSEGV (0xb) at pc=0x00000001045f2a10, pid=12345, tid=259
            #
            # Problematic frame:
            # C  [libglfw.dylib+0x12a10]  _glfwPlatformCreateWindow+0x40
            #
            """
        ),
        .init(
            "符号缺失",
            cause: "有 mod 和游戏或其他 mod 不兼容",
            fragments: ["net.minecraft.client.Minecraft.tick()"],
            gameLog: "java.lang.NoSuchMethodError: 'void net.minecraft.client.Minecraft.tick()'"
        ),
        .init(
            "类文件缺失",
            cause: "缺少某个 mod 需要的前置",
            fragments: ["net/fabricmc/fabric/api/client/rendering/v1/WorldRenderEvents"],
            gameLog: "Caused by: java.lang.NoClassDefFoundError: net/fabricmc/fabric/api/client/rendering/v1/WorldRenderEvents"
        ),
        .init(
            "泛化的加载失败",
            cause: "mod 加载失败",
            gameLog: "net.minecraftforge.fml.LoadingFailedException: Loading errors encountered"
        ),
        .init(
            "未知异常",
            cause: "未能识别出崩溃原因",
            fragments: ["Unexpected error", "java.lang.NullPointerException", "examplemod"],
            crashReport: """
            Description: Unexpected error

            java.lang.NullPointerException: Cannot invoke "net.minecraft.world.entity.Entity.tick()" because "entity" is null
            \tat TRANSFORMER/minecraft@1.20.1/net.minecraft.client.Minecraft.tick(Minecraft.java:1000)
            \tat TRANSFORMER/examplemod@1.0.0/com.example.mixin.EntityMixin.onTick(EntityMixin.java:42)
            """
        ),
        .init(
            "被信号终止",
            cause: "游戏被系统强行结束",
            fragments: ["SIGSEGV"],
            gameLog: normalLog,
            exitCode: 11
        ),
        .init(
            "没有任何输出",
            cause: "游戏几乎没有输出任何日志",
            exitCode: 1
        ),
        .init(
            "无崩溃报告的顶层异常",
            cause: "游戏启动时出错，未能识别出原因",
            fragments: ["cloth-config not loaded"],
            gameLog: """
            [16:35:36] [main/INFO]: Loading 214 mods
            [16:37:20] [Render thread/ERROR]: Failed to recreate fishing hook on client
            Exception in thread "main" java.lang.RuntimeException: cloth-config not loaded
            \tat com.example.ExampleMod.init(ExampleMod.java:42)
            """
        )
    ]

    // MARK: - 规则匹配

    /// 每个样本都应被分析出预期的首要原因，且建议中包含预期的提取信息。
    @Test func testSamplesMatchExpectedCause() {
        for sample in Self.samples {
            let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(sample.context)
            guard let primary = results.first else {
                Issue.record("样本「\(sample.name)」未命中任何规则，期望「\(sample.expectedCause)」")
                continue
            }
            #expect(primary.cause == sample.expectedCause, "样本「\(sample.name)」的首要原因不符")
            let text: String = primary.suggestion + (primary.details ?? "")
            for fragment in sample.expectedFragments {
                #expect(text.contains(fragment), "样本「\(sample.name)」的结论中缺少「\(fragment)」")
            }
        }
    }

    /// 展示给玩家的原因与建议中不应出现异常类名、堆栈等术语，它们只能出现在技术信息里。
    @Test func testSuggestionsAvoidJargon() {
        let jargon: [String] = ["Exception", "Error:", "java.lang", "at TRANSFORMER", "NullPointer", "ClassNotFound", ".mixins."]
        for sample in Self.samples {
            guard let primary = CrashAnalyzer.analyze(sample.context).first else { continue }
            for word in jargon {
                #expect(!primary.cause.contains(word), "原因「\(primary.cause)」中出现了术语「\(word)」")
                #expect(
                    !primary.suggestion.contains(word),
                    "样本「\(sample.name)」的建议中出现了术语「\(word)」，应移到技术信息中"
                )
            }
        }
    }

    /// 玩家名含中文属于风险提示，不能盖过日志中已经查明的具体原因。
    @Test func testPlayerNameHintDoesNotOverrideSpecificCause() {
        let context: CrashContext = .init(
            gameLog: "java.lang.OutOfMemoryError: Java heap space",
            playerName: "小明"
        )
        let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(context)
        #expect(results.first?.cause == "内存不足")
        #expect(!results.contains { $0.cause == "玩家名包含中文或特殊字符" })
    }

    /// 每条规则都必须有至少一个测试样本，防止新增规则时漏测。
    @Test func testEveryRuleIsCovered() {
        let coveredCauses: Set<String> = .init(Self.samples.map(\.expectedCause))
        let uncovered: [String] = CrashRules.all.map(\.cause).filter { !coveredCauses.contains($0) }
        #expect(uncovered.isEmpty, "以下规则缺少测试样本：\(uncovered.joined(separator: "、"))")
    }

    /// 规则的原因描述不应重复，否则弹窗中会出现两条相同的原因。
    @Test func testCausesAreUnique() {
        let causes: [String] = CrashRules.all.map(\.cause)
        #expect(Set(causes).count == causes.count)
    }

    // MARK: - 规则表整体行为

    /// 同时命中多条具体规则时，更靠前的规则作为首要原因，其余作为次要原因一并返回。
    @Test func testSecondaryCausesAreReported() {
        let gameLog: String = """
        java.lang.OutOfMemoryError: Java heap space
        Maybe try a lower resolution resourcepack?
        """
        let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(.init(gameLog: gameLog))
        #expect(results.first?.cause == "材质包分辨率太高")
        #expect(results.contains { $0.cause == "内存不足" })
    }

    /// 具体规则命中时，兜底规则不应参与匹配。
    @Test func testFallbackSkippedWhenSpecificMatched() {
        let gameLog: String = """
        org.spongepowered.asm.mixin.throwables.MixinApplyError: Mixin apply failed
        Caused by: java.lang.ClassNotFoundException: net.example.MissingClass
        """
        let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(.init(gameLog: gameLog))
        #expect(results.count == 1)
        #expect(results.first?.cause == "某个 mod 修改游戏时出错")
    }

    /// 崩溃报告的调用栈中会附带大量无关 mod 的 Mixin 信息，不应把它们误认成出错的 Mixin。
    @Test func testMixinAttributionIgnoresStackDecorations() {
        let crashReport: String = """
        Description: Unexpected error

        org.spongepowered.asm.mixin.transformer.throwables.MixinTransformerError: An unexpected critical error was encountered
        \tat TRANSFORMER/minecraft@1.21.1/net.minecraft.client.renderer.LevelRenderer.render(LevelRenderer.java:1) {pl:mixin:APP:supplementaries.mixins.json:LevelRendererMixin from mod supplementaries,pl:mixin:APP:create.mixins.json:client.LevelRendererMixin from mod create}
        Caused by: org.spongepowered.asm.mixin.transformer.throwables.MixinPreProcessorException: Attach error for mixins.iris.compat.sodium.json:MixinRenderSectionManager from mod iris during activity: [Transform]
        """
        let result: CrashAnalysisResult? = CrashAnalyzer.analyze(.init(crashReport: crashReport)).first
        let text: String = (result?.suggestion ?? "") + (result?.details ?? "")
        #expect(result?.suggestion.contains("Iris") == true, "应当向玩家点明出错的 mod")
        #expect(text.contains("mixins.iris.compat.sodium.json"))
        #expect(!text.contains("supplementaries"))
        #expect(!text.contains("create.mixins.json"))
    }

    /// Mixin 扫描 JDK 内部类时打印的类文件版本警告不会导致崩溃，不应被误判为 Java 版本过高。
    @Test func testClassVersionWarningIsNotACause() {
        let gameLog: String = """
        [18:33:13] [main/INFO]: [MemoryLeakFix] Currently enabled memory leak fixes: [targetEntityLeak]
        [18:33:13] [main/WARN]: Error loading class: java/lang/invoke/MethodHandles$Lookup (java.lang.IllegalArgumentException: Unsupported class file major version 69)
        [18:33:14] [main/WARN]: Error loading class: net/minecraft/client/Minecraft (java.lang.IllegalArgumentException: Unsupported class file major version 69)
        """
        let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(.init(gameLog: gameLog))
        #expect(!results.contains { $0.cause == "Java 版本太新" })
    }

    /// 游戏日志中的登录失败、Realms 报错等噪声不应盖过崩溃报告给出的真实原因。
    @Test func testGameLogNoiseDoesNotOverrideCrashReport() {
        let gameLog: String = """
        [16:35:36] [Download-2/INFO]: Could not authorize you against Realms server: HTTP 401 Unauthorized
        [16:35:36] [Download-2/ERROR]: Failed to fetch Realms feature flags
        com.mojang.authlib.exceptions.InvalidCredentialsException: Status: 401
        """
        let crashReport: String = """
        Description: Ticking entity

        java.lang.NullPointerException: Cannot invoke "net.minecraft.world.level.Level.getBlockState()" because "level" is null
        """
        let results: [CrashAnalysisResult] = CrashAnalyzer.analyze(.init(gameLog: gameLog, crashReport: crashReport))
        #expect(results.first?.cause == "某个游戏内容导致了崩溃")
        #expect(!results.contains { $0.cause == "账号登录被拒绝" })
    }

    // MARK: - mod 名称对照

    /// 对照表应支持按 mod ID 与包名前缀两种方式查询，且包名取最长匹配。
    @Test func testModNameTableLookup() {
        #expect(ModNameTable.displayName(forModID: "sodium") == "Sodium")
        #expect(ModNameTable.displayName(forModID: "SODIUM") == "Sodium")
        #expect(ModNameTable.displayName(forClassName: "dev/tr7zw/skinlayers/render/CustomizableModelPart") == "3D Skin Layers")
        #expect(ModNameTable.displayName(forClassName: "com.github.alexthe666.citadel.server.Foo") == "Citadel")
        #expect(ModNameTable.displayName(for: "distanthorizons") == "Distant Horizons（超远视距）")
        #expect(ModNameTable.displayName(for: "从未出现过的东西") == nil)
        // 前缀相同但更具体的条目应当胜出
        #expect(ModNameTable.displayName(forClassName: "com.github.alexthe666.alexsmobs.entity.Bear") == "Alex's Mobs")
    }

    /// 对照表中查得到的 mod，应当以玩家认得出的名字展示，而不是原始 mod ID。
    @Test func testModNamesAreHumanReadable() {
        let crashReport: String = """
        Description: Ticking entity

        java.lang.NullPointerException: Cannot invoke "net.minecraft.world.level.Level.getBlockState()" because "level" is null

        -- Entity being ticked --
        Details:
        \tEntity Type: alexsmobs:grizzly_bear (com.github.alexthe666.alexsmobs.entity.EntityGrizzlyBear)
        """
        let result: CrashAnalysisResult? = CrashAnalyzer.analyze(.init(crashReport: crashReport)).first
        #expect(result?.suggestion.contains("Alex's Mobs") == true)
    }

    /// 对照表里没有的 mod 应当原样显示 mod ID，不能因为查不到就丢失信息。
    @Test func testUnknownModFallsBackToID() {
        let crashReport: String = """
        Description: Ticking entity

        java.lang.NullPointerException: something is null

        -- Entity being ticked --
        Details:
        \tEntity Type: someunknownmod:strange_creature (com.example.Strange)
        """
        let result: CrashAnalysisResult? = CrashAnalyzer.analyze(.init(crashReport: crashReport)).first
        #expect(result?.suggestion.contains("someunknownmod") == true)
    }

    /// 正常的游戏日志不应命中任何规则。
    @Test func testNoMatch() {
        #expect(CrashAnalyzer.analyze(.init(gameLog: Self.normalLog)).isEmpty)
    }

    // MARK: - 上下文加载

    /// `since` 早于文件修改时间时能找到文件，晚于时应被过滤。
    @Test func testLatestFileFreshness() throws {
        let directory: URL = FileManager.default.temporaryDirectory.appending(path: "CrashAnalyzerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory.appending(path: "crash-reports"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let crashReportURL: URL = directory.appending(path: "crash-reports/crash-2026-08-10_12.00.00-client.txt")
        try "Description: Unexpected error".write(to: crashReportURL, atomically: true, encoding: .utf8)
        let hsErrURL: URL = directory.appending(path: "hs_err_pid12345.log")
        try "# A fatal error has been detected".write(to: hsErrURL, atomically: true, encoding: .utf8)

        #expect(CrashAnalyzer.latestCrashReport(in: directory, since: .distantPast)?.resolvingSymlinksInPath().path == crashReportURL.resolvingSymlinksInPath().path)
        #expect(CrashAnalyzer.latestHsErrLog(in: directory, since: .distantPast)?.resolvingSymlinksInPath().path == hsErrURL.resolvingSymlinksInPath().path)
        #expect(CrashAnalyzer.latestCrashReport(in: directory, since: .distantFuture) == nil)
        #expect(CrashAnalyzer.latestHsErrLog(in: directory, since: .distantFuture) == nil)
    }
}

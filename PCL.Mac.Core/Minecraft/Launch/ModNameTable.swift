//
//  ModNameTable.swift
//  PCL.Mac
//
//  Created by yuanmua on 2026/8/10.
//

import Foundation

/// mod 名称对照表。
///
/// 崩溃日志里出现的是 mod ID（如 `distanthorizons`）或 Java 包名（如 `dev.tr7zw.skinlayers`），
/// 玩家不一定认得出它对应的是哪个 mod。这张表把它们翻译成玩家在下载页面见到的名字，
/// 让崩溃分析能直接说出“问题出在《超远视距》上”。
///
/// 这张表是人工维护的，不求全，只求准：
/// - 查不到时崩溃分析会原样显示 mod ID，不会出错，因此可以随用随加。
/// - 新增条目时请确认名称与实际 mod 一致，宁可不写也不要写错。
/// - `modIDs` 的键用小写 mod ID；`packagePrefixes` 的键用包名前缀，越具体的前缀优先级越高。
public enum ModNameTable {
    /// mod ID 到显示名的对照。键必须为小写。
    public static let modIDs: [String: String] = [
        // MARK: 加载器与前置库
        "fabricloader": "Fabric 加载器",
        "fabric": "Fabric API",
        "fabric-api": "Fabric API",
        "forge": "Forge 加载器",
        "neoforge": "NeoForge 加载器",
        "kotlinforforge": "Kotlin for Forge",
        "fabric-language-kotlin": "Fabric Language Kotlin",
        "mixinextras": "MixinExtras",
        "architectury": "Architectury API",
        "clothconfig": "Cloth Config",
        "cloth-config": "Cloth Config",
        "cloth_config": "Cloth Config",
        "balm": "Balm",
        "citadel": "Citadel",
        "curios": "Curios API",
        "geckolib": "GeckoLib",
        "geckolib3": "GeckoLib",
        "mantle": "Mantle",
        "moonlight": "Moonlight Lib",
        "patchouli": "Patchouli",
        "placebo": "Placebo",
        "supermartijn642corelib": "SuperMartijn642's Core Lib",
        "yungsapi": "YUNG's API",
        "cicada": "CICADA",
        "oelib": "OeLib",
        "sophisticatedcore": "Sophisticated Core",
        "flywheel": "Flywheel",
        "ponder": "Ponder",
        "xaerolib": "Xaero 系列前置",

        // MARK: 优化与渲染
        "sodium": "Sodium",
        "embeddium": "Embeddium",
        "rubidium": "Rubidium",
        "iris": "Iris 光影加载器",
        "oculus": "Oculus 光影加载器",
        "optifine": "OptiFine",
        "lithium": "Lithium",
        "starlight": "Starlight",
        "ferritecore": "FerriteCore",
        "modernfix": "ModernFix",
        "memoryleakfix": "Memory Leak Fix",
        "entityculling": "Entity Culling",
        "immediatelyfast": "ImmediatelyFast",
        "alternate_current": "Alternate Current",
        "distanthorizons": "Distant Horizons（超远视距）",
        "notenoughcrashes": "Not Enough Crashes",

        // MARK: 界面与工具
        "jei": "JEI（物品管理器）",
        "roughlyenoughitems": "REI（物品管理器）",
        "rei": "REI（物品管理器）",
        "jade": "Jade（方块信息）",
        "wthit": "WTHIT（方块信息）",
        "modmenu": "Mod Menu",
        "fancymenu": "FancyMenu",
        "journeymap": "JourneyMap（小地图）",
        "xaerominimap": "Xaero's Minimap（小地图）",
        "xaeroworldmap": "Xaero's World Map（世界地图）",
        "pingwheel": "Ping Wheel（标记轮盘）",
        "appleskin": "AppleSkin",
        "i18nupdatemod": "I18nUpdateMod（汉化更新）",
        "skinshuffle": "SkinShuffle",
        "skinlayers": "3D Skin Layers",
        "skinlayers3d": "3D Skin Layers",
        "cosmeticarmorreworked": "Cosmetic Armor Reworked",

        // MARK: 内容 mod
        "create": "Create（机械动力）",
        "railways": "Create: Steam 'n' Rails",
        "sliceanddice": "Create: Slice & Dice",
        "alexsmobs": "Alex's Mobs",
        "iceandfire": "Ice and Fire",
        "twilightforest": "The Twilight Forest（暮色森林）",
        "botania": "Botania（植物魔法）",
        "mekanism": "Mekanism（通用机械）",
        "immersiveengineering": "Immersive Engineering（沉浸工程）",
        "appliedenergistics2": "Applied Energistics 2（应用能源 2）",
        "ae2": "Applied Energistics 2（应用能源 2）",
        "refinedstorage": "Refined Storage（精致存储）",
        "tconstruct": "Tinkers' Construct（匠魂）",
        "farmersdelight": "Farmer's Delight（农夫乐事）",
        "supplementaries": "Supplementaries",
        "decorative_blocks": "Decorative Blocks",
        "framedblocks": "FramedBlocks",
        "rechiseled": "Rechiseled",
        "sereneseasons": "Serene Seasons（四季）",
        "sophisticatedbackpacks": "Sophisticated Backpacks",
        "ironchest": "Iron Chests（铁质箱子）",
        "corpse": "Corpse（死亡尸体）",
        "exposure": "Exposure（相机）",
        "fairylights": "Fairy Lights",
        "do_a_barrel_roll": "Do a Barrel Roll",
        "touhou_little_maid": "东方女仆（Touhou Little Maid）",
        "biolith": "Biolith",
        "kubejs": "KubeJS"
    ]

    /// Java 包名前缀到显示名的对照。用于从崩溃堆栈里的类名反推 mod。
    ///
    /// 匹配时取最长的那个前缀，因此可以先写一个宽泛的前缀，之后再补更具体的。
    public static let packagePrefixes: [String: String] = [
        "net.caffeinemc": "Sodium",
        "me.jellysquid.mods.sodium": "Sodium",
        "me.jellysquid.mods.lithium": "Lithium",
        "net.irisshaders": "Iris 光影加载器",
        "net.optifine": "OptiFine",
        "mezz.jei": "JEI（物品管理器）",
        "me.shedaniel.rei": "REI（物品管理器）",
        "me.shedaniel.clothconfig": "Cloth Config",
        "dev.architectury": "Architectury API",
        "com.simibubi.create": "Create（机械动力）",
        "com.railwayteam.railways": "Create: Steam 'n' Rails",
        "dev.engine_room.flywheel": "Flywheel",
        "software.bernie.geckolib": "GeckoLib",
        "com.llamalad7.mixinextras": "MixinExtras",
        "dev.tr7zw.skinlayers": "3D Skin Layers",
        "com.mineblock11.skinshuffle": "SkinShuffle",
        "squeek.appleskin": "AppleSkin",
        "com.github.alexthe666.alexsmobs": "Alex's Mobs",
        "com.github.alexthe666.citadel": "Citadel",
        "de.maxhenkel.corpse": "Corpse（死亡尸体）",
        "lain.mods.cos": "Cosmetic Armor Reworked",
        "xaero": "Xaero 系列",
        "dev.latvian.mods.kubejs": "KubeJS",
        "vazkii.patchouli": "Patchouli",
        "vazkii.botania": "Botania（植物魔法）",
        "net.blay09.mods.balm": "Balm",
        "vectorwing.farmersdelight": "Farmer's Delight（农夫乐事）",
        "slimeknights.tconstruct": "Tinkers' Construct（匠魂）",
        "slimeknights.mantle": "Mantle",
        "appeng": "Applied Energistics 2（应用能源 2）",
        "mekanism": "Mekanism（通用机械）",
        "twilightforest": "The Twilight Forest（暮色森林）",
        "org.violetmoon.quark": "Quark",
        "com.teamresourceful.resourcefullib": "Resourceful Lib"
    ]

    /// 查询一个 mod ID 对应的显示名。
    /// - Parameter modID: mod ID，大小写不敏感。
    /// - Returns: 显示名。表中没有时返回 `nil`。
    public static func displayName(forModID modID: String) -> String? {
        modIDs[modID.lowercased()]
    }

    /// 从类名或包名反推 mod 的显示名，取最长匹配的前缀。
    /// - Parameter className: 类名或包名，`/` 与 `.` 两种分隔符都可以。
    /// - Returns: 显示名。表中没有时返回 `nil`。
    public static func displayName(forClassName className: String) -> String? {
        let normalized: String = className.replacingOccurrences(of: "/", with: ".").lowercased()
        return packagePrefixes
            .filter { normalized == $0.key || normalized.hasPrefix($0.key + ".") }
            .max { $0.key.count < $1.key.count }?
            .value
    }

    /// 查询一个标识对应的显示名，先按 mod ID 查，再按包名前缀查。
    /// - Parameter identifier: mod ID、类名或包名。
    /// - Returns: 显示名。表中没有时返回 `nil`。
    public static func displayName(for identifier: String) -> String? {
        displayName(forModID: identifier) ?? displayName(forClassName: identifier)
    }
}

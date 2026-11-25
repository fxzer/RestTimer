import Foundation

/// 休息全屏主题（4×3 共 12 款：静音冷调系 + 柔和护眼系 + 静谧深色极光系）
enum BreakGradientTheme: String, Codable, CaseIterable, Equatable {
    case autoDayNight
    case frostedGlass
    case graphiteMist
    case slateIce
    case midnightViolet
    case celadonEyeCare
    case warmPaper
    case amberGlow
    case mistyTeal
    case forestMoss
    case auroraOcean
    case sunsetAmber
    case smokyRose

    /// 全部具象可选主题（不含自动轮换，4 列 × 3 行）
    static let concreteThemes: [BreakGradientTheme] = [
        .frostedGlass, .graphiteMist, .slateIce, .midnightViolet,
        .celadonEyeCare, .warmPaper, .amberGlow, .mistyTeal,
        .forestMoss, .auroraOcean, .sunsetAmber, .smokyRose
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = BreakGradientTheme(rawValue: raw) ?? .autoDayNight
    }

    var displayName: String {
        switch self {
        case .autoDayNight: return "自动轮换"
        case .frostedGlass: return "毛玻璃"
        case .graphiteMist: return "石墨灰"
        case .slateIce: return "冰岩蓝"
        case .midnightViolet: return "夜幕紫"
        case .celadonEyeCare: return "豆沙绿"
        case .warmPaper: return "暖羊皮"
        case .amberGlow: return "琥珀金"
        case .mistyTeal: return "晨雾蓝"
        case .forestMoss: return "森林绿"
        case .auroraOcean: return "深海蓝"
        case .sunsetAmber: return "暮光霞"
        case .smokyRose: return "烟玫瑰"
        }
    }

    var isFrostedDesktop: Bool {
        self == .frostedGlass
    }
}

/// 久坐康复运动五大核心部位（按从头到脚顺序：颈部 -> 肩背 -> 手腕 -> 腰脊 -> 臀腿，每个部位 3 至 5 张同款 3:4 插图）
enum StretchCategory: Int, CaseIterable, Comparable, Equatable {
    case neck = 0
    case shoulderBack = 1
    case wristForearm = 2
    case waistSpine = 3
    case glutesLegs = 4

    static func < (lhs: StretchCategory, rhs: StretchCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var regionName: String {
        switch self {
        case .neck: return "颈部"
        case .shoulderBack: return "肩背"
        case .wristForearm: return "手腕"
        case .waistSpine: return "腰脊"
        case .glutesLegs: return "臀腿"
        }
    }

    var symbolName: String {
        switch self {
        case .neck: return "person.bust.fill"
        case .shoulderBack: return "figure.arms.open"
        case .wristForearm: return "hand.raised.fill"
        case .waistSpine: return "figure.cooldown"
        case .glutesLegs: return "figure.walk"
        }
    }

    func badgeText(requiresStanding: Bool) -> String {
        "\(requiresStanding ? "站姿" : "坐姿") · \(regionName)"
    }
}

/// 运动视觉资产：统一采用 3:4 比例白底橘红肌群高亮插画
enum StretchVisualAsset: Equatable {
    case fitgateIllustration(assetName: String)
}

/// 单个办公室久坐康复动作模型
struct StretchExercise: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let category: StretchCategory
    let recommendedSeconds: Int
    let requiresStanding: Bool
    let mirrorAtHalfway: Bool
    let steps: [String]
    let safetyTip: String
    let visual: StretchVisualAsset

    var badgeText: String {
        category.badgeText(requiresStanding: requiresStanding)
    }
}

/// 办公室久坐运动与名言智能编排器（五大部位全覆盖，按从头到脚顺序排列，共 20 个动作）
enum StretchRoutinePlanner {
    static let catalog: [StretchExercise] = [
        // ================= 一、颈部（5 个动作：上斜方肌 / 斜角肌 / 肩胛提肌 / 胸锁乳突肌 / 枕下肌群） =================
        StretchExercise(
            id: "neck-01-behind-back",
            name: "背后交扣侧头",
            subtitle: "上斜方肌与颈侧拉伸",
            category: .neck,
            recommendedSeconds: 45,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "挺背沉肩，双手在背后十指交扣压住双肩",
                "头部平缓倒向一侧拉伸对侧颈肩，半程换边"
            ],
            safetyTip: "保持双肩自然下沉平稳呼吸，切勿用力拉扯头部",
            visual: .fitgateIllustration(assetName: "fg_03_behind_neck")
        ),
        StretchExercise(
            id: "neck-02-ear-shoulder",
            name: "耳朵找肩膀",
            subtitle: "颈侧斜角肌拉伸",
            category: .neck,
            recommendedSeconds: 45,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "挺背沉肩，头部向一侧平缓倾斜使耳朵靠近肩膀",
                "同侧手轻搭头顶引导方向，切勿发力下拽"
            ],
            safetyTip: "手掌仅借自重轻搭，缓解单侧颈肌紧绷",
            visual: .fitgateIllustration(assetName: "fg_04_ear_shoulder")
        ),
        StretchExercise(
            id: "neck-03-look-armpit",
            name: "低头看腋窝",
            subtitle: "肩胛提肌精准放松",
            category: .neck,
            recommendedSeconds: 45,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "坐直沉肩，头向一侧水平转 45 度后微收下巴",
                "低头看向同侧腋窝，同侧手轻扶后脑勺稳定"
            ],
            safetyTip: "缓解后颈与肩胛内上角僵硬",
            visual: .fitgateIllustration(assetName: "fg_05_look_armpit")
        ),
        StretchExercise(
            id: "neck-04-press-collarbone",
            name: "手按锁骨看斜上方",
            subtitle: "胸锁乳突肌与颈前舒展",
            category: .neck,
            recommendedSeconds: 40,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "双手重叠按住锁骨交界处，轻微向下牵引固定",
                "头部转向一侧、目光望向对侧斜上方，半程换边"
            ],
            safetyTip: "对抗颈部前探，注意不要过度向后折颈",
            visual: .fitgateIllustration(assetName: "fg_06_press_collarbone")
        ),
        StretchExercise(
            id: "neck-05-hold-head-down",
            name: "托住后脑微收下巴",
            subtitle: "枕下肌群减压",
            category: .neck,
            recommendedSeconds: 35,
            requiresStanding: false,
            mirrorAtHalfway: false,
            steps: [
                "挺直腰背，双手十指交扣托在后脑勺枕骨下方",
                "微收下巴，顺应头部重力平缓低垂，勿用手下压"
            ],
            safetyTip: "缓解后脑勺发紧与眼眶酸胀",
            visual: .fitgateIllustration(assetName: "fg_07_hold_head_down")
        ),

        // ================= 二、肩背（4 个动作：三角肌后束 / 胸大肌背阔肌 / 菱形肌 / 胸小肌） =================
        StretchExercise(
            id: "shoulder-01-cross-body",
            name: "跨胸水平拉肩",
            subtitle: "三角肌后束与肩胛骨缝拉伸",
            category: .shoulderBack,
            recommendedSeconds: 40,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "挺背沉肩，一侧手臂伸直水平横过胸前",
                "另一手前臂扣住手肘向胸口轻拉，半程换边"
            ],
            safetyTip: "拉开肩部后侧与肩胛骨内侧缘紧绷肌群",
            visual: .fitgateIllustration(assetName: "fg_17_cross_shoulder")
        ),
        StretchExercise(
            id: "shoulder-02-raise-hands",
            name: "举手翻掌",
            subtitle: "胸廓与背阔肌上举舒展",
            category: .shoulderBack,
            recommendedSeconds: 35,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "双脚与肩同宽站立，双手十指交扣举过头顶",
                "翻转掌心朝上推引伸展，双肩微后展、收腹不塌腰"
            ],
            safetyTip: "打开双臂内旋与含胸姿态",
            visual: .fitgateIllustration(assetName: "fg_01_raise_hands")
        ),
        StretchExercise(
            id: "shoulder-03-arms-rotate",
            name: "胳膊向后旋",
            subtitle: "上背菱形肌与中下斜方肌激活",
            category: .shoulderBack,
            recommendedSeconds: 35,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "自然站立挺胸收腹，双臂向两侧水平展开与肩同高",
                "握空拳带动手臂向后旋转，两侧肩胛骨向中线夹紧"
            ],
            safetyTip: "主动激活上背肌群，改善圆肩驼背",
            visual: .fitgateIllustration(assetName: "fg_02_arms_rotate")
        ),
        StretchExercise(
            id: "shoulder-04-wall-chest",
            name: "靠墙开胸",
            subtitle: "胸小肌与前肩舒展",
            category: .shoulderBack,
            recommendedSeconds: 40,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "面向墙面一臂距离站立，双肘小臂贴墙或手放颈后",
                "上身缓慢前移使胸口靠向墙面，深呼吸展开前胸"
            ],
            safetyTip: "以墙面为支点安全拉开内扣胸肩",
            visual: .fitgateIllustration(assetName: "fg_08_wall_chest")
        ),

        // ================= 三、手腕与前臂（3 个动作：前臂屈肌 / 前臂伸肌 / 双侧腕屈肌腱） =================
        StretchExercise(
            id: "wrist-01-flexor-stretch",
            name: "伸臂掌心向外压腕",
            subtitle: "前臂屈肌群与腕管减压",
            category: .wristForearm,
            recommendedSeconds: 40,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "一侧手臂向前伸直，掌心向外、指尖朝下",
                "另一手轻扳四指向身体方向牵拉，半程换手"
            ],
            safetyTip: "释放长时间敲击键盘引起的前臂内侧紧绷",
            visual: .fitgateIllustration(assetName: "fg_18_wrist_flexor")
        ),
        StretchExercise(
            id: "wrist-02-extensor-stretch",
            name: "伸臂手背向上压腕",
            subtitle: "前臂伸肌群舒展",
            category: .wristForearm,
            recommendedSeconds: 40,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "一侧手臂向前伸直，手背朝上、指尖自然垂下",
                "另一手轻按手背向身体方向牵拉，半程换手"
            ],
            safetyTip: "缓解长时间握持鼠标引起的手腕与前臂外侧酸胀",
            visual: .fitgateIllustration(assetName: "fg_19_wrist_extensor")
        ),
        StretchExercise(
            id: "wrist-03-prayer-stretch",
            name: "胸前合十下压展腕",
            subtitle: "双侧腕关节与指屈肌腱舒展",
            category: .wristForearm,
            recommendedSeconds: 35,
            requiresStanding: false,
            mirrorAtHalfway: false,
            steps: [
                "双手在胸前合十掌根贴紧，双肘向两侧水平展开",
                "保持掌根相贴缓慢向下移动，感受手腕内侧延展"
            ],
            safetyTip: "温和对称拉开双侧腕管与手指屈肌腱",
            visual: .fitgateIllustration(assetName: "fg_20_prayer_wrist")
        ),

        // ================= 四、腰部与脊柱（4 个动作：胸腰旋转 / 腰椎后伸 / 竖脊肌后链 / 腰方肌侧屈） =================
        StretchExercise(
            id: "waist-01-seated-twist",
            name: "坐姿扶椅背转体",
            subtitle: "胸腰椎旋转与侧腰松解",
            category: .waistSpine,
            recommendedSeconds: 45,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "坐直固定骨盆朝前，一手扶椅背、一手搭对侧大腿",
                "呼气带动胸腔与肩膀向后平缓旋转，半程换边"
            ],
            safetyTip: "保持脊柱向上拔高再旋转，切勿弓背猛扭",
            visual: .fitgateIllustration(assetName: "fg_21_seated_spinal_twist")
        ),
        StretchExercise(
            id: "waist-02-back-extension",
            name: "扶腰后伸",
            subtitle: "腰椎后伸减压",
            category: .waistSpine,
            recommendedSeconds: 45,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "双脚与肩同宽站立，双手叉腰稳固托住后腰上缘",
                "以双手为支点，上身平缓向后仰伸 5 秒后回正"
            ],
            safetyTip: "双手稳固托住后腰，平衡久坐前屈的腰椎负荷",
            visual: .fitgateIllustration(assetName: "fg_09_waist_stretch")
        ),
        StretchExercise(
            id: "waist-03-swallow-fly",
            name: "站姿小燕飞",
            subtitle: "竖脊肌与后侧链综合激活",
            category: .waistSpine,
            recommendedSeconds: 45,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "双脚与肩同宽站稳，双肩后展，双臂向身后斜下伸直",
                "骨盆微前移、胸腔抬起，向后延伸保持 4 秒后回正"
            ],
            safetyTip: "温和激活背部与臀上侧肌群",
            visual: .fitgateIllustration(assetName: "fg_10_swallow_fly")
        ),
        StretchExercise(
            id: "waist-04-side-bend",
            name: "交叉腿叉腰侧屈",
            subtitle: "单侧腰方肌与侧腹拉伸",
            category: .waistSpine,
            recommendedSeconds: 45,
            requiresStanding: true,
            mirrorAtHalfway: true,
            steps: [
                "站立一手叉腰，对侧腿交叉跨至斜后方脚尖点地",
                "另一手屈肘放耳侧，上身向叉腰侧平缓侧弯，半程换边"
            ],
            safetyTip: "缓解单侧腰部肌群紧绷",
            visual: .fitgateIllustration(assetName: "fg_14_cross_leg_side_bend")
        ),

        // ================= 五、臀部与大小腿（4 个动作：臀部梨状肌 / 小腿腓肠肌 / 大腿后侧腘绳肌 / 臀腿复合深蹲） =================
        StretchExercise(
            id: "legs-01-seated-figure-four",
            name: "坐姿架腿前倾拉臀",
            subtitle: "臀部深层梨状肌与臀中肌拉伸",
            category: .glutesLegs,
            recommendedSeconds: 45,
            requiresStanding: false,
            mirrorAtHalfway: true,
            steps: [
                "坐姿将一侧脚踝架在对侧膝盖上方，双手轻扶小腿",
                "保持腰背挺直，从髋部带动上身微向前倾，半程换腿"
            ],
            safetyTip: "深层松解久坐受压的臀部梨状肌，预防坐骨神经酸麻",
            visual: .fitgateIllustration(assetName: "fg_22_seated_figure_four")
        ),
        StretchExercise(
            id: "legs-02-under-desk-ankle",
            name: "坐姿勾脚踮脚",
            subtitle: "小腿腓肠肌与静脉泵促回流",
            category: .glutesLegs,
            recommendedSeconds: 40,
            requiresStanding: false,
            mirrorAtHalfway: false,
            steps: [
                "坐姿双脚用力向上勾起脚尖，保持 2 秒拉伸小腿",
                "随后脚尖下踩、抬高脚后跟踮起 2 秒，交替重复"
            ],
            safetyTip: "激活小腿静脉泵，促进下肢血液回流",
            visual: .fitgateIllustration(assetName: "fg_13_under_desk_ankle")
        ),
        StretchExercise(
            id: "legs-03-hamstring-stretch",
            name: "屈膝屈髋伸腿拉后侧",
            subtitle: "大腿后侧腘绳肌与下背筋膜拉伸",
            category: .glutesLegs,
            recommendedSeconds: 45,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "双脚与肩同宽屈膝下蹲，双手扶稳脚面或地面支撑",
                "向上推动臀部并尽量伸直双腿保持 4 秒，感受大腿后侧拉伸"
            ],
            safetyTip: "利用双手支撑保护腰椎，安全拉开久坐缩短的大腿后侧",
            visual: .fitgateIllustration(assetName: "fg_11_hamstring_stretch")
        ),
        StretchExercise(
            id: "legs-04-standard-squat",
            name: "站姿标准深蹲",
            subtitle: "臀大肌、股四头肌与下肢促循环",
            category: .glutesLegs,
            recommendedSeconds: 45,
            requiresStanding: true,
            mirrorAtHalfway: false,
            steps: [
                "双脚略宽于肩脚尖微外展，挺直背部屈髋屈膝平稳下蹲",
                "膝盖朝向脚尖方向，全脚掌踩实蹬地站直，匀速重复"
            ],
            safetyTip: "调动臀腿大肌群，打破久坐代谢停滞",
            visual: .fitgateIllustration(assetName: "fg_15_squat")
        )
    ]

    static var quotes: [CuratedQuote] { CuratedQuoteLibrary.all }

    /// 根据休息总秒数智能编排，并按从头到脚（颈 -> 肩背 -> 手腕 -> 腰脊 -> 臀腿）部位顺序排列
    static func planRoutine(
        forBreakSeconds totalSeconds: Int,
        excludingRecentIds recentIds: Set<String> = []
    ) -> [StretchExercise] {
        let clampedSeconds = max(15, totalSeconds)

        if clampedSeconds <= 75 {
            let targetCount = clampedSeconds <= 40 ? 1 : 2
            let seatedPool = catalog.filter { !$0.requiresStanding }
            return sortByCatalogOrder(selectBalanced(from: seatedPool, count: targetCount, excluding: recentIds))
        }

        let targetCount = min(8, max(2, Int(round(Double(clampedSeconds) / 42.0))))
        var selected: [StretchExercise] = []
        var usedIds = Set<String>()

        for category in StretchCategory.allCases {
            guard selected.count < targetCount else { break }
            let fresh = catalog.filter {
                $0.category == category && !usedIds.contains($0.id) && !recentIds.contains($0.id)
            }
            if let pick = fresh.randomElement() {
                selected.append(pick)
                usedIds.insert(pick.id)
            }
        }

        if selected.count < targetCount {
            let remaining = selectBalanced(
                from: catalog.filter { !usedIds.contains($0.id) },
                count: targetCount - selected.count,
                excluding: recentIds
            )
            selected.append(contentsOf: remaining)
        }

        return sortByCatalogOrder(selected)
    }

    private static func sortByCatalogOrder(_ list: [StretchExercise]) -> [StretchExercise] {
        let indexMap = Dictionary(uniqueKeysWithValues: catalog.enumerated().map { ($1.id, $0) })
        return list.sorted { (indexMap[$0.id] ?? 0) < (indexMap[$1.id] ?? 0) }
    }

    private static func selectBalanced(
        from pool: [StretchExercise],
        count: Int,
        excluding recentIds: Set<String>
    ) -> [StretchExercise] {
        guard count > 0, !pool.isEmpty else { return [] }
        let fresh = pool.filter { !recentIds.contains($0.id) }.shuffled()
        let fallback = pool.filter { recentIds.contains($0.id) }.shuffled()
        return Array((fresh + fallback).prefix(count))
    }
}

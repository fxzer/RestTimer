import Foundation

/// 结构化名言模型
struct CuratedQuote: Equatable {
    let text: String
    let author: String
}

/// 精选可考名言库（60 条真实原句，覆盖古籍诗词、中外文学、哲学思想与科学工程；采用洗牌袋算法，全部轮完再重洗，杜绝连续重复）
enum CuratedQuoteLibrary {
    static let all: [CuratedQuote] = [
        // MARK: - 一、中国古籍与诗词（18 条）
        CuratedQuote(text: "形劳而不倦，精神不散，亦可以百数。", author: "《黄帝内经·素问》"),
        CuratedQuote(text: "久视伤血，久卧伤气，久坐伤肉。", author: "《黄帝内经·素问》"),
        CuratedQuote(text: "张而不弛，文武弗能也；弛而不张，文武弗为也。", author: "《礼记·杂记下》"),
        CuratedQuote(text: "知止而后有定，定而后能静，静而后能安。", author: "《礼记·大学》"),
        CuratedQuote(text: "户枢不蠹，流水不腐，形气亦然。", author: "《吕氏春秋》"),
        CuratedQuote(text: "虚室生白，吉祥止止。", author: "《庄子·人间世》"),
        CuratedQuote(text: "人生天地之间，若白驹之过隙，忽然而已。", author: "《庄子·知北游》"),
        CuratedQuote(text: "致虚极，守静笃。万物并作，吾以观复。", author: "《道德经》"),
        CuratedQuote(text: "不疾而速，不行而至。", author: "《周易·系辞上》"),
        CuratedQuote(text: "风来疏竹，风过而竹不留声；雁渡寒潭，雁去而潭不留影。", author: "洪应明《菜根谭》"),
        CuratedQuote(text: "宠辱不惊，闲看庭前花开花落；去留无意，漫随天外云卷云舒。", author: "洪应明《菜根谭》"),
        CuratedQuote(text: "行到水穷处，坐看云起时。", author: "王维《终南别业》"),
        CuratedQuote(text: "采菊东篱下，悠然见南山。", author: "陶渊明《饮酒》"),
        CuratedQuote(text: "问君何能尔？心远地自偏。", author: "陶渊明《饮酒》"),
        CuratedQuote(text: "竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生。", author: "苏轼《定风波》"),
        CuratedQuote(text: "回首向来萧瑟处，归去，也无风雨也无晴。", author: "苏轼《定风波》"),
        CuratedQuote(text: "且将新火试新茶，诗酒趁年华。", author: "苏轼《望江南》"),
        CuratedQuote(text: "因过竹院逢僧话，偷得浮生半日闲。", author: "李涉《题鹤林寺僧舍》"),

        // MARK: - 二、中外文学与随笔（16 条）
        CuratedQuote(text: "真正懂得享受人生的人，是懂得如何善用闲暇的人。", author: "林语堂《生活的艺术》"),
        CuratedQuote(text: "一定要爱着点什么，恰似草木对光阴的钟情。", author: "汪曾祺《人间草木》"),
        CuratedQuote(text: "我行过许多地方的桥，看过许多次数的云。", author: "沈从文"),
        CuratedQuote(text: "你若爱，生活哪里都可爱。", author: "丰子恺"),
        CuratedQuote(text: "太阳，它每时每刻都是夕阳也都是旭日。", author: "史铁生《我与地坛》"),
        CuratedQuote(text: "我和谁都不争，和谁争我都不屑。", author: "兰德（杨绛译）"),
        CuratedQuote(text: "休息时不要想着工作，工作时不要想着休息。", author: "列夫·托尔斯泰"),
        CuratedQuote(text: "时间只是我垂钓的溪流。", author: "亨利·戴维·梭罗《瓦尔登湖》"),
        CuratedQuote(text: "如果一个人跟不上同伴的步伐，或许是因为他听到了不同的鼓声。", author: "亨利·戴维·梭罗《瓦尔登湖》"),
        CuratedQuote(text: "真正的发现之旅不在于寻找新风景，而在于拥有新的眼光。", author: "马塞尔·普鲁斯特"),
        CuratedQuote(text: "对未来真正的慷慨，是把一切献给现在。", author: "阿尔贝·加缪《反抗者》"),
        CuratedQuote(text: "在隆冬，我终于知道，我身上有一个不可战胜的夏天。", author: "阿尔贝·加缪《重返蒂帕萨》"),
        CuratedQuote(text: "不必急着寻找答案，先去活出这些问题本身。", author: "里尔克《给青年诗人的信》"),
        CuratedQuote(text: "世界以痛吻我，要我报之以歌。", author: "泰戈尔《飞鸟集》"),
        CuratedQuote(text: "生如夏花之绚烂，死如秋叶之静美。", author: "泰戈尔《飞鸟集》"),
        CuratedQuote(text: "万物皆有裂痕，那是光照进来的地方。", author: "莱昂纳德·科恩"),

        // MARK: - 三、哲学与思想（14 条）
        CuratedQuote(text: "君子坦荡荡，小人长戚戚。", author: "《论语·述而》"),
        CuratedQuote(text: "质胜文则野，文胜质则史，文质彬彬，然后君子。", author: "《论语·雍也》"),
        CuratedQuote(text: "破山中贼易，破心中贼难。", author: "王阳明"),
        CuratedQuote(text: "我们受的苦，往往更多来自想象，而非现实。", author: "塞涅卡《道德书简》"),
        CuratedQuote(text: "并不是我们拥有的时间太短，而是我们浪费的太多。", author: "塞涅卡《论生命之短暂》"),
        CuratedQuote(text: "你无法控制外在事件，但你永远掌控着自己的心念。", author: "马可·奥勒留《沉思录》"),
        CuratedQuote(text: "宇宙即变化，人生即念头。", author: "马可·奥勒留《沉思录》"),
        CuratedQuote(text: "困扰人的并非事物本身，而是人对事物的看法。", author: "爱比克泰德《手册》"),
        CuratedQuote(text: "人类一切的不幸，都源于无法独自安静地待在房间里。", author: "布莱兹·帕斯卡《思想录》"),
        CuratedQuote(text: "能善用闲暇，是文明的终极考验。", author: "伯特兰·罗素《闲散颂》"),
        CuratedQuote(text: "凡不可说者，必当沉默。", author: "维特根斯坦《逻辑哲学论》"),
        CuratedQuote(text: "健康胜过一切外在的恩赐。", author: "叔本华《人生的智慧》"),
        CuratedQuote(text: "我们反复做的事造就了我们；卓越不是一种行为，而是一种习惯。", author: "威尔·杜兰特"),
        CuratedQuote(text: "认清生活真相之后依然热爱生活，才是真正的英雄主义。", author: "罗曼·罗兰"),

        // MARK: - 四、科学、艺术与工程大师（12 条）
        CuratedQuote(text: "一切都应尽可能简单，但不能过于简单。", author: "阿尔伯特·爱因斯坦"),
        CuratedQuote(text: "人生就像骑自行车，想保持平衡就得不断前行。", author: "阿尔伯特·爱因斯坦"),
        CuratedQuote(text: "偶尔停下来休息一下，当你回去工作时，判断力会更敏锐。", author: "列奥纳多·达·芬奇《笔记》"),
        CuratedQuote(text: "简洁是终极的复杂。", author: "列奥纳多·达·芬奇"),
        CuratedQuote(text: "好的设计是尽可能少的设计。", author: "迪特·拉姆斯"),
        CuratedQuote(text: "专注和简单一直是我的信条；简单比复杂更难。", author: "史蒂夫·乔布斯"),
        CuratedQuote(text: "保持专注的秘诀，是学会对一百件好主意说不。", author: "史蒂夫·乔布斯"),
        CuratedQuote(text: "第一原则是绝不能欺骗自己，而你自己正是最容易被骗的人。", author: "理查德·费曼"),
        CuratedQuote(text: "过早优化是万恶之源。", author: "高德纳（Donald Knuth）"),
        CuratedQuote(text: "在自然的每一次漫步中，人得到的都远超他所追寻的。", author: "约翰·缪尔"),
        CuratedQuote(text: "一个敢于浪费一小时时间的人，还没有发现生命的价值。", author: "查尔斯·达尔文"),
        CuratedQuote(text: "早睡早起使人健康、富有而明智。", author: "本杰明·富兰克林")
    ]

    /// 洗牌袋状态：确保 60 条名言全部轮播一遍后再重新洗牌，避免短时间内撞句
    private static var shuffledBag: [CuratedQuote] = []

    static func resetBag() {
        shuffledBag.removeAll()
    }

    static func nextQuote(excluding current: CuratedQuote? = nil) -> CuratedQuote {
        guard !all.isEmpty else {
            return CuratedQuote(text: "形劳而不倦，精神不散。", author: "《黄帝内经·素问》")
        }
        if shuffledBag.isEmpty {
            shuffledBag = all.shuffled()
            if let current = current, shuffledBag.count > 1, shuffledBag.last == current {
                shuffledBag.swapAt(0, shuffledBag.count - 1)
            }
        }
        return shuffledBag.removeLast()
    }
}

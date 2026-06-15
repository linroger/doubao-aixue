//
//  ContentCatalog.swift
//  豆包爱学
//
//  Bundled sample content so the app is rich and demoable offline. Mirrors the
//  real product's first 豆包课堂 batch (classical-Chinese poetry) plus sample
//  word units, dictation lists, a knowledge graph, and practice problems.
//

import Foundation

public nonisolated enum ContentCatalog {

    // MARK: 豆包课堂 — classical-Chinese poetry (first real batch + more)

    public static let poems: [CatalogPoem] = [
        CatalogPoem(
            title: "七步诗", dynasty: "三国·魏", author: "曹植",
            original: "煮豆持作羹，漉菽以为汁。\n萁在釜下燃，豆在釜中泣。\n本自同根生，相煎何太急？",
            translation: "煮豆子用来做羹，过滤豆子取汁。豆秸在锅底燃烧，豆子在锅中哭泣。本是同一根上生长，为何要这样急迫地煎熬彼此？",
            appreciation: "以“同根”比喻同胞兄弟，借煮豆之事控诉骨肉相残，构思巧妙、情感真挚，是“咏物言志”的典范。",
            grade: .g6),
        CatalogPoem(
            title: "夏日绝句", dynasty: "宋", author: "李清照",
            original: "生当作人杰，死亦为鬼雄。\n至今思项羽，不肯过江东。",
            translation: "活着就要做人中豪杰，死了也要做鬼中英雄。到今天人们还思念项羽，因为他宁死不肯逃回江东。",
            appreciation: "借古讽今，以项羽的气节反衬南宋统治者的苟且，慷慨激昂，气势磅礴。",
            grade: .g6),
        CatalogPoem(
            title: "水调歌头·明月几时有", dynasty: "宋", author: "苏轼",
            original: "明月几时有？把酒问青天。\n不知天上宫阙，今夕是何年。\n……\n但愿人长久，千里共婵娟。",
            translation: "明月什么时候才有？我端起酒杯询问青天。不知道天上的宫殿，今晚是哪一年。……只希望人能长久平安，即使相隔千里也能共赏这美好的月亮。",
            appreciation: "由问月到怀人，由出世到入世，情理交融，旷达中见深情，是中秋词的千古绝唱。",
            grade: .g8),
        CatalogPoem(
            title: "出塞", dynasty: "唐", author: "王昌龄",
            original: "秦时明月汉时关，万里长征人未还。\n但使龙城飞将在，不教胡马度阴山。",
            translation: "依旧是秦汉时的明月和边关，远征万里的将士仍未归还。只要镇守龙城的飞将军还在，绝不会让敌人的战马越过阴山。",
            appreciation: "以雄浑笔触写边塞，时空交叠，寄托对良将的渴望与卫国情怀，被誉为“唐人七绝压卷之作”。",
            grade: .g7),
        CatalogPoem(
            title: "早发白帝城", dynasty: "唐", author: "李白",
            original: "朝辞白帝彩云间，千里江陵一日还。\n两岸猿声啼不住，轻舟已过万重山。",
            translation: "清晨告别彩云缭绕的白帝城，千里之外的江陵一天就能返回。两岸猿猴的啼声还在耳边回响，轻快的小船已驶过万重高山。",
            appreciation: "以轻快流畅的节奏写归途之畅快，景中含情，洋溢着遇赦后的喜悦与豪情。",
            grade: .g5),
        CatalogPoem(
            title: "静夜思", dynasty: "唐", author: "李白",
            original: "床前明月光，疑是地上霜。\n举头望明月，低头思故乡。",
            translation: "明亮的月光洒在床前，好像地上泛起了白霜。抬头望着天上的明月，低头不禁思念起故乡。",
            appreciation: "语言朴素自然，由“望月”到“思乡”，以小见大，道尽游子心声，千古传诵。",
            grade: .g3),
    ]

    /// 豆包课堂 courses (PGC, mapped from the poems + a few subjects).
    public static var courses: [CatalogCourse] {
        poems.map {
            CatalogCourse(title: $0.title, author: $0.author, dynasty: $0.dynasty, subject: .chinese,
                          grade: $0.grade, summary: "沉浸式AI视频课：情景短片 + 知识点精讲。\($0.appreciation)",
                          durationSec: 600, isUGC: false)
        } + [
            CatalogCourse(title: "鸡兔同笼的多种解法", author: "豆包老师", dynasty: "", subject: .math,
                          grade: .g4, summary: "从抬腿法到方程法，按年级理解经典数学问题。", durationSec: 540),
            CatalogCourse(title: "英语时态全景图", author: "豆包老师", dynasty: "", subject: .english,
                          grade: .g8, summary: "用一张图理清一般/进行/完成时态的用法。", durationSec: 600),
        ]
    }

    // MARK: 背单词 — sample English unit

    public static let englishUnit: [CatalogWord] = [
        CatalogWord(headword: "improve", phonetic: "/ɪmˈpruːv/", definition: "v. 改善；提高",
                    examples: ["I want to improve my English.", "Practice improves your skills."]),
        CatalogWord(headword: "knowledge", phonetic: "/ˈnɒlɪdʒ/", definition: "n. 知识；学问",
                    examples: ["Knowledge is power.", "She has a wide knowledge of history."]),
        CatalogWord(headword: "achieve", phonetic: "/əˈtʃiːv/", definition: "v. 实现；取得",
                    examples: ["Hard work helps you achieve your goals."]),
        CatalogWord(headword: "challenge", phonetic: "/ˈtʃælɪndʒ/", definition: "n. 挑战 v. 向…挑战",
                    examples: ["This problem is a real challenge."]),
        CatalogWord(headword: "memory", phonetic: "/ˈmeməri/", definition: "n. 记忆；回忆",
                    examples: ["He has a good memory for names."]),
        CatalogWord(headword: "confident", phonetic: "/ˈkɒnfɪdənt/", definition: "adj. 自信的",
                    examples: ["Be confident in the exam!"]),
    ]

    // MARK: 听写 — sample lists

    public static let dictationChinese: [DictationEntry] = [
        DictationEntry(text: "理想", reading: "lǐ xiǎng", meaning: "对未来的美好设想"),
        DictationEntry(text: "勤奋", reading: "qín fèn", meaning: "勤劳奋发"),
        DictationEntry(text: "坚持", reading: "jiān chí", meaning: "持续不放弃"),
        DictationEntry(text: "探索", reading: "tàn suǒ", meaning: "多方寻求答案"),
        DictationEntry(text: "成长", reading: "chéng zhǎng", meaning: "向成熟发展"),
    ]

    public static let dictationEnglish: [DictationEntry] = englishUnit.map {
        DictationEntry(text: $0.headword, reading: $0.phonetic, meaning: $0.definition)
    }

    // MARK: 知识图谱 — sample knowledge points

    public static let knowledgePoints: [CatalogKnowledgePoint] = [
        CatalogKnowledgePoint(id: "math.arith", name: "四则运算", subject: .math, grade: .g3,
                              summary: "加减乘除及其运算顺序。", chapter: "数与代数"),
        CatalogKnowledgePoint(id: "math.equation", name: "一元一次方程", subject: .math, grade: .g7,
                              summary: "含一个未知数、次数为1的方程及解法。", chapter: "方程与不等式", parentIDs: ["math.arith"]),
        CatalogKnowledgePoint(id: "math.fraction", name: "分数运算", subject: .math, grade: .g5,
                              summary: "分数的加减乘除与通分约分。", chapter: "数与代数", parentIDs: ["math.arith"]),
        CatalogKnowledgePoint(id: "math.geometry.area", name: "图形面积", subject: .math, grade: .g5,
                              summary: "常见平面图形面积公式与割补法。", chapter: "图形与几何"),
        CatalogKnowledgePoint(id: "cn.reading", name: "阅读理解", subject: .chinese, grade: .g6,
                              summary: "把握文意、定位关键句、概括中心。", chapter: "现代文阅读"),
        CatalogKnowledgePoint(id: "cn.classical", name: "文言文翻译", subject: .chinese, grade: .g8,
                              summary: "实词虚词、句式与断句。", chapter: "古诗文"),
        CatalogKnowledgePoint(id: "en.tense", name: "时态", subject: .english, grade: .g8,
                              summary: "一般/进行/完成时态的构成与用法。", chapter: "语法"),
        CatalogKnowledgePoint(id: "en.words", name: "词汇运用", subject: .english, grade: .g7,
                              summary: "常用词的搭配与辨析。", chapter: "词汇"),
        CatalogKnowledgePoint(id: "phy.force", name: "受力分析", subject: .physics, grade: .g8,
                              summary: "识别物体所受的力并作受力图。", chapter: "力学"),
    ]

    // MARK: Sample practice problems

    public static let sampleProblems: [CatalogProblem] = [
        CatalogProblem(subject: .math, text: "125 × 8 = ?", answer: "1000"),
        CatalogProblem(subject: .math, text: "小明有 24 颗糖，平均分给 6 个朋友，每人几颗？", answer: "4"),
        CatalogProblem(subject: .math, text: "一个长方形长 8 厘米，宽 5 厘米，面积是多少？", answer: "40 平方厘米"),
        CatalogProblem(subject: .chinese, text: "解释“熟能生巧”的意思。", answer: "熟练了就能产生巧办法，比喻经常练习就能掌握技巧。"),
        CatalogProblem(subject: .english, text: "Choose: She ___ to school every day. A. go B. goes C. going", answer: "B"),
    ]

    public static let sampleArithmetic: [ArithmeticItem] = [
        ArithmeticItem(expression: "12 + 7", studentAnswer: "19"),
        ArithmeticItem(expression: "8 × 9", studentAnswer: "72"),
        ArithmeticItem(expression: "45 ÷ 5", studentAnswer: "8"),       // wrong → 9
        ArithmeticItem(expression: "100 - 37", studentAnswer: "63"),
        ArithmeticItem(expression: "6 × 7 + 3", studentAnswer: "45"),
        ArithmeticItem(expression: "(4 + 6) × 3", studentAnswer: "30"),
    ]

    public static let sampleEssay = """
    我的理想是成为一名科学家。每当我仰望星空，总会好奇宇宙的奥秘。科学家可以探索未知，帮助人们解决问题。为了实现这个理想，我要认真学习，勤于思考，遇到困难也不放弃。我相信，只要坚持努力，理想一定会实现。
    """
}

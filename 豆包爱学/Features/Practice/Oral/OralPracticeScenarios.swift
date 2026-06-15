//
//  OralPracticeScenarios.swift
//  豆包爱学 — Features/Practice/Oral
//
//  Pure value-type content for 英语口语 / 口语陪练 (F36): the role-play scenarios
//  (购物 / 自我介绍 / 问路), the switchable avatars/voices, and each scenario's
//  scripted turns. Every turn carries the model's English line, its Chinese gloss,
//  and a suggested student line so the call screen can show "model speaks → you
//  reply → score". Common student slips are encoded as `OralCorrection`s so the
//  feature can surface a wrong→right correction bubble when the recognised
//  transcript contains a known mistake.
//
//  All types are `nonisolated` Codable/Sendable value types — they are touched by
//  the view model and previews and must cross isolation cleanly.
//

import Foundation

// MARK: - Scenario

/// A role-play situation the student practises. Doubao plays the other speaker
/// (shopkeeper / new friend / passer-by) and the student responds in turn.
nonisolated enum OralScenario: String, CaseIterable, Identifiable, Codable, Sendable {
    case introduction   // 自我介绍
    case shopping       // 购物
    case directions     // 问路
    case restaurant     // 点餐
    case schoolDay      // 校园生活

    var id: String { rawValue }

    /// Chinese title shown on the scenario chip.
    var title: String {
        switch self {
        case .introduction: "自我介绍"
        case .shopping: "购物"
        case .directions: "问路"
        case .restaurant: "餐厅点餐"
        case .schoolDay: "校园生活"
        }
    }

    /// One-line Chinese description for the picker.
    var subtitle: String {
        switch self {
        case .introduction: "和新朋友打招呼，介绍自己"
        case .shopping: "在商店买东西，问价格、试穿"
        case .directions: "向路人问路，听懂指引"
        case .restaurant: "在餐厅点餐、加单、结账"
        case .schoolDay: "聊聊课程、社团和一天的安排"
        }
    }

    var systemImage: String {
        switch self {
        case .introduction: "hand.wave.fill"
        case .shopping: "bag.fill"
        case .directions: "signpost.right.fill"
        case .restaurant: "fork.knife"
        case .schoolDay: "backpack.fill"
        }
    }

    /// English label for the role Doubao plays in this scenario.
    var partnerRole: String {
        switch self {
        case .introduction: "New friend"
        case .shopping: "Shopkeeper"
        case .directions: "Passer-by"
        case .restaurant: "Waiter"
        case .schoolDay: "Classmate"
        }
    }

    /// Chinese label for the role Doubao plays.
    var partnerRoleCN: String {
        switch self {
        case .introduction: "新朋友"
        case .shopping: "店员"
        case .directions: "路人"
        case .restaurant: "服务员"
        case .schoolDay: "同学"
        }
    }

    /// The scripted turns for this scenario.
    var turns: [OralTurnScript] {
        switch self {
        case .introduction: Self.introductionTurns
        case .shopping: Self.shoppingTurns
        case .directions: Self.directionsTurns
        case .restaurant: Self.restaurantTurns
        case .schoolDay: Self.schoolDayTurns
        }
    }
}

// MARK: - Turn script

/// One exchange: Doubao speaks `modelLine`, then the student is expected to say
/// something close to `suggestedReply`. `gloss` is the Chinese meaning of the
/// model line (shown under the subtitle), and `hint` nudges the student.
nonisolated struct OralTurnScript: Identifiable, Codable, Sendable, Hashable {
    var id: Int
    var modelLine: String
    var gloss: String
    var suggestedReply: String
    var hint: String

    init(id: Int, modelLine: String, gloss: String, suggestedReply: String, hint: String) {
        self.id = id
        self.modelLine = modelLine
        self.gloss = gloss
        self.suggestedReply = suggestedReply
        self.hint = hint
    }
}

// MARK: - Correction

/// A common spoken slip → its corrected form, shown as a wrong→right bubble when
/// the recognised transcript contains the trigger. Encodes the "instant
/// correction inline" behaviour from RESEARCH F36.
nonisolated struct OralCorrection: Codable, Sendable, Hashable, Identifiable {
    var id: String { wrong }
    var wrong: String
    var right: String
    var note: String

    init(wrong: String, right: String, note: String) {
        self.wrong = wrong
        self.right = right
        self.note = note
    }
}

// MARK: - Avatar / voice

/// A switchable partner persona. `voiceLanguage` is the BCP-47 tag handed to
/// `TTSService.speak` so the student can hear a US / UK accent.
nonisolated struct OralAvatar: Identifiable, Codable, Sendable, Hashable {
    var id: String
    var name: String
    var personaCN: String
    var voiceLanguage: String
    var rate: Float

    init(id: String, name: String, personaCN: String, voiceLanguage: String, rate: Float) {
        self.id = id
        self.name = name
        self.personaCN = personaCN
        self.voiceLanguage = voiceLanguage
        self.rate = rate
    }

    nonisolated static let all: [OralAvatar] = [
        OralAvatar(id: "amy", name: "Amy", personaCN: "美音 · 亲切", voiceLanguage: "en-US", rate: 0.46),
        OralAvatar(id: "leo", name: "Leo", personaCN: "美音 · 活力", voiceLanguage: "en-US", rate: 0.5),
        OralAvatar(id: "olivia", name: "Olivia", personaCN: "英音 · 温柔", voiceLanguage: "en-GB", rate: 0.45),
        OralAvatar(id: "noah", name: "Noah", personaCN: "英音 · 稳重", voiceLanguage: "en-GB", rate: 0.48),
    ]

    nonisolated static let `default` = all[0]
}

// MARK: - Scripts

extension OralScenario {

    nonisolated static let introductionTurns: [OralTurnScript] = [
        OralTurnScript(id: 0,
                       modelLine: "Hi there! Nice to meet you. What's your name?",
                       gloss: "你好！很高兴认识你。你叫什么名字？",
                       suggestedReply: "Hi, my name is Lily. Nice to meet you too.",
                       hint: "用 my name is … 介绍自己的名字。"),
        OralTurnScript(id: 1,
                       modelLine: "Cool! How old are you, and where are you from?",
                       gloss: "酷！你多大了，来自哪里？",
                       suggestedReply: "I am twelve years old, and I am from Beijing.",
                       hint: "说年龄用 I am … years old，说家乡用 I am from …。"),
        OralTurnScript(id: 2,
                       modelLine: "Nice! What do you like to do in your free time?",
                       gloss: "真好！你空闲时间喜欢做什么？",
                       suggestedReply: "I like reading books and playing basketball.",
                       hint: "用 I like + 动词-ing 说爱好。"),
        OralTurnScript(id: 3,
                       modelLine: "That sounds fun. I hope we can be good friends!",
                       gloss: "听起来很有趣。希望我们能成为好朋友！",
                       suggestedReply: "Me too! Let's be friends.",
                       hint: "礼貌地回应，表达也想成为朋友。"),
    ]

    nonisolated static let shoppingTurns: [OralTurnScript] = [
        OralTurnScript(id: 0,
                       modelLine: "Welcome to our store! Can I help you?",
                       gloss: "欢迎光临！有什么可以帮您的吗？",
                       suggestedReply: "Yes, I am looking for a blue T-shirt.",
                       hint: "用 I am looking for … 说出你想买的东西。"),
        OralTurnScript(id: 1,
                       modelLine: "Sure. What size do you need?",
                       gloss: "好的。您需要什么尺码？",
                       suggestedReply: "I need a medium size, please.",
                       hint: "尺码常说 small / medium / large。"),
        OralTurnScript(id: 2,
                       modelLine: "Here you are. It is twenty dollars.",
                       gloss: "给您。这件二十美元。",
                       suggestedReply: "That's a good price. I will take it.",
                       hint: "想买就说 I will take it。"),
        OralTurnScript(id: 3,
                       modelLine: "Great choice! How would you like to pay?",
                       gloss: "好眼光！您想怎么付款？",
                       suggestedReply: "I will pay by card, thank you.",
                       hint: "付款方式：by card / in cash。"),
    ]

    nonisolated static let directionsTurns: [OralTurnScript] = [
        OralTurnScript(id: 0,
                       modelLine: "Excuse me, you look a little lost. Do you need help?",
                       gloss: "打扰一下，你看起来有点迷路。需要帮忙吗？",
                       suggestedReply: "Yes, how can I get to the train station?",
                       hint: "问路用 How can I get to …？"),
        OralTurnScript(id: 1,
                       modelLine: "Go straight ahead, then turn left at the bank.",
                       gloss: "一直往前走，在银行那里左转。",
                       suggestedReply: "Go straight and turn left. Is it far?",
                       hint: "复述指引，再问 Is it far?"),
        OralTurnScript(id: 2,
                       modelLine: "No, it is about five minutes on foot.",
                       gloss: "不远，步行大约五分钟。",
                       suggestedReply: "Great. Thank you so much for your help.",
                       hint: "礼貌道谢用 Thank you so much。"),
        OralTurnScript(id: 3,
                       modelLine: "You're welcome. Have a nice day!",
                       gloss: "不客气。祝你今天愉快！",
                       suggestedReply: "You too! Goodbye.",
                       hint: "回应祝福用 You too!"),
    ]

    nonisolated static let restaurantTurns: [OralTurnScript] = [
        OralTurnScript(id: 0,
                       modelLine: "Good evening! Are you ready to order?",
                       gloss: "晚上好！您准备好点餐了吗？",
                       suggestedReply: "Yes, I would like a beef burger, please.",
                       hint: "点餐用 I would like …, please。"),
        OralTurnScript(id: 1,
                       modelLine: "Sure. Would you like anything to drink?",
                       gloss: "好的。您想喝点什么吗？",
                       suggestedReply: "Can I have a glass of orange juice?",
                       hint: "要饮料用 Can I have …？"),
        OralTurnScript(id: 2,
                       modelLine: "Of course. Anything else for you?",
                       gloss: "当然。还需要别的吗？",
                       suggestedReply: "No, that's all. Thank you.",
                       hint: "够了就说 That's all。"),
        OralTurnScript(id: 3,
                       modelLine: "Your meal will be ready soon. Enjoy!",
                       gloss: "您的餐很快就好。请慢用！",
                       suggestedReply: "Thank you. It smells delicious.",
                       hint: "夸赞食物用 It smells delicious。"),
    ]

    nonisolated static let schoolDayTurns: [OralTurnScript] = [
        OralTurnScript(id: 0,
                       modelLine: "Hey! What is your favourite subject at school?",
                       gloss: "嘿！你在学校最喜欢哪门课？",
                       suggestedReply: "My favourite subject is English.",
                       hint: "用 My favourite subject is …。"),
        OralTurnScript(id: 1,
                       modelLine: "Nice! Do you join any clubs after class?",
                       gloss: "不错！课后你参加社团吗？",
                       suggestedReply: "Yes, I am in the music club.",
                       hint: "说社团用 I am in the … club。"),
        OralTurnScript(id: 2,
                       modelLine: "That's great. How do you go to school every day?",
                       gloss: "真棒。你每天怎么去上学？",
                       suggestedReply: "I usually go to school by bus.",
                       hint: "交通方式用 by bus / by bike / on foot。"),
        OralTurnScript(id: 3,
                       modelLine: "Sounds like a busy day! See you tomorrow.",
                       gloss: "听起来很充实！明天见。",
                       suggestedReply: "See you tomorrow! Bye.",
                       hint: "道别用 See you tomorrow!"),
    ]
}

// MARK: - Corrections

extension OralCorrection {
    /// A small bank of frequent K12 spoken-English slips. The view model scans the
    /// recognised transcript for any `wrong` form and surfaces the matching bubble.
    nonisolated static let bank: [OralCorrection] = [
        OralCorrection(wrong: "i am twelve years",       right: "I am twelve years old",
                       note: "说年龄别忘了 old：I am twelve years old."),
        OralCorrection(wrong: "i very like",             right: "I really like",
                       note: "英语里说 I really like，不说 I very like。"),
        OralCorrection(wrong: "how to get to",           right: "How can I get to",
                       note: "问路要用完整句 How can I get to …？"),
        OralCorrection(wrong: "i am from of",            right: "I am from",
                       note: "from 后面直接跟地点，不加 of。"),
        OralCorrection(wrong: "more better",             right: "better",
                       note: "better 已是比较级，不能再加 more。"),
        OralCorrection(wrong: "i will take it please",   right: "I will take it, please",
                       note: "记得在 please 前停顿，语气更自然。"),
    ]

    /// Find the first correction whose trigger appears in `transcript`
    /// (case-insensitive). Returns `nil` when the utterance has no known slip.
    static func match(in transcript: String) -> OralCorrection? {
        let lowered = transcript.lowercased()
        return bank.first { lowered.contains($0.wrong) }
    }
}

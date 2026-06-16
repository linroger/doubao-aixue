//
//  SampleData.swift
//  豆包爱学
//
//  Seeds rich first-run content so the app is immediately full of life:
//  a profile, courses, a word deck, dictation lists, a knowledge graph with
//  mastery, sample mistakes, a welcome conversation, plans and streaks.
//

import Foundation
import SwiftData

@MainActor
public enum SampleData {

    public static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<LearnerProfile>())) ?? 0
        guard existing == 0 else { return }
        seed(context)
        context.saveLogging()
    }

    /// Force a full reseed (used by "restore sample data" in settings).
    public static func reset(_ context: ModelContext) {
        for type in ModelContainerFactory.models {
            try? context.delete(model: type)
        }
        seed(context)
        context.saveLogging()
    }

    private static func seed(_ context: ModelContext) {
        // Profile (onboarded so the shell is immediately populated).
        let profile = LearnerProfile()
        profile.nickname = "小豆"
        profile.grade = .g5
        profile.subjects = [.math, .chinese, .english]
        profile.editions = [.math: .renjiao, .chinese: .renjiao, .english: .waiyan]
        profile.onboardingComplete = true
        profile.streakDays = 7
        profile.problemsSolved = 128
        context.insert(profile)

        // Streak + parent controls.
        let streak = StudyStreak()
        streak.current = 7; streak.longest = 21; streak.lastCheckIn = Date()
        context.insert(streak)
        context.insert(ParentControls())

        // Knowledge points + mastery.
        let masteries: [String: Double] = [
            "math.arith": 0.92, "math.equation": 0.45, "math.fraction": 0.7,
            "math.geometry.area": 0.3, "cn.reading": 0.8, "cn.classical": 0.4,
            "en.tense": 0.55, "en.words": 0.85, "phy.force": 0.25,
        ]
        for kp in ContentCatalog.knowledgePoints {
            let entity = KnowledgePointEntity()
            entity.id = kp.id; entity.name = kp.name; entity.subject = kp.subject
            entity.grade = kp.grade; entity.summary = kp.summary; entity.chapter = kp.chapter
            entity.parentIDs = kp.parentIDs
            context.insert(entity)

            let m = MasteryRecord()
            m.knowledgePointID = kp.id; m.subject = kp.subject
            m.score = masteries[kp.id] ?? 0.5
            m.attempts = 12; m.correctCount = Int(12 * (masteries[kp.id] ?? 0.5))
            context.insert(m)
        }

        // 豆包课堂 courses — original 8 from ContentCatalog, enhanced with real lesson
        // script (LessonContentCatalog) where a matching (subject, grade) entry exists.
        for c in ContentCatalog.courses {
            let course = CourseEntity()
            course.title = c.title; course.author = c.author; course.dynasty = c.dynasty
            course.subject = c.subject; course.grade = c.grade; course.summary = c.summary
            course.durationSec = c.durationSec; course.isUGC = c.isUGC
            if let lesson = LessonContentCatalog.lesson(subject: c.subject, grade: c.grade) {
                course.segments = lesson.segments
            } else {
                course.segments = MockContent.lessonSegments(topic: c.title, subject: c.subject)
            }
            context.insert(course)
        }

        // Full curriculum coverage — one CourseEntity per (subject, grade) bucket from
        // LessonContentCatalog, skipping buckets already covered above. This lands all
        // scripted lessons (87 total, minus duplicates) into the 豆包课堂 on first run.
        let covered = Set(ContentCatalog.courses.map { "\($0.subject.rawValue).\($0.grade.rawValue)" })
        for lesson in LessonContentCatalog.lessons {
            let key = "\(lesson.subject.rawValue).\(lesson.grade.rawValue)"
            if covered.contains(key) { continue }
            let course = CourseEntity()
            course.title = lesson.topic
            course.author = "豆包老师"
            course.dynasty = ""
            course.subject = lesson.subject
            course.grade = lesson.grade
            course.summary = "豆包课堂 · \(lesson.subject.displayName) · \(lesson.grade.displayName)"
            course.durationSec = 540
            course.isUGC = false
            course.segments = lesson.segments
            context.insert(course)
        }

        // Word deck (背单词).
        let deck = WordDeck()
        deck.name = "外研版 七年级 Unit 1"; deck.subject = .english; deck.grade = .g7; deck.unit = "Unit 1"
        context.insert(deck)
        for (i, w) in ContentCatalog.englishUnit.enumerated() {
            let card = WordCard()
            card.headword = w.headword; card.phonetic = w.phonetic
            card.definition = w.definition; card.examples = w.examples
            card.dueDate = Calendar.current.date(byAdding: .day, value: i % 3 - 1, to: Date()) ?? Date()
            card.deck = deck
            context.insert(card)
        }

        // Dictation lists (听写).
        let zh = DictationList()
        zh.name = "语文 词语听写"; zh.language = .chinese; zh.unit = "第一单元"
        zh.entries = ContentCatalog.dictationChinese
        context.insert(zh)
        let en = DictationList()
        en.name = "English Spelling"; en.language = .english; en.unit = "Unit 1"
        en.entries = ContentCatalog.dictationEnglish
        context.insert(en)

        // Sample mistakes (错题本).
        let mistakeSeeds: [(Subject, String, String, String, ErrorType, [String])] = [
            (.math, "45 ÷ 5 = ?", "8", "9", .calculation, ["math.arith"]),
            (.math, "解方程 2x + 3 = 11", "x = 5", "x = 4", .method, ["math.equation"]),
            (.english, "She ___ to school. (go)", "go", "goes", .knowledgeGap, ["en.tense"]),
            (.chinese, "“熟能生巧”的意思", "很熟练", "熟练了就能掌握技巧", .comprehension, ["cn.reading"]),
        ]
        for (subject, q, studentAns, correct, type, kps) in mistakeSeeds {
            let m = MistakeItem()
            m.subject = subject; m.questionText = q; m.studentAnswer = studentAns
            m.correctAnswer = correct; m.errorType = type; m.knowledgePointIDs = kps
            m.errorReason = "再巩固一下相关知识点。"
            m.mastery = .weak
            m.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            m.steps = [SolutionStep(index: 1, title: "回顾", detail: "正确答案是 \(correct)。")]
            context.insert(m)
        }

        // Sample 题库 (question bank) so the feature — and 智能出题 — are explorable
        // immediately and never start empty.
        let bankSeeds: [(Subject, WorkbookQuestionType, String, String, BankSource, [String], [String])] = [
            (.math, .application, "一个长方形长 8 厘米，宽 5 厘米，面积是多少？", "40 平方厘米", .workbook, ["math.geometry.area"], ["长方形面积"]),
            (.math, .calculation, "36 + 48 = ?", "84", .workbook, ["math.arith"], ["进位加法"]),
            (.english, .multipleChoice, "She ___ to school every day.  A. go  B. goes  C. going", "B", .solve, ["en.tense"], ["第三人称单数"]),
            (.chinese, .fillInBlank, "《静夜思》：举头望明月，低头思______。", "故乡", .manual, ["cn.classical"], ["古诗默写"]),
        ]
        for (subject, type, q, ans, source, kpIDs, kpNames) in bankSeeds {
            let item = BankedQuestion()
            item.subject = subject; item.type = type
            item.questionText = q; item.correctAnswer = ans
            item.explanation = "复习时先自己作答，再核对答案。"
            item.source = source
            item.knowledgePointIDs = kpIDs
            item.knowledgePointNames = kpNames
            item.mastery = .weak
            item.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            context.insert(item)
        }

        // Welcome conversation.
        let convo = Conversation()
        convo.title = "欢迎来到豆包爱学"; convo.kindRaw = "knowledge"
        context.insert(convo)
        let hi = ChatMessageEntity()
        hi.role = .assistant
        hi.text = "你好，我是豆包！拍张照片、问个问题，或者让我陪你听写、背单词都可以。今天想从哪里开始？"
        hi.conversation = convo
        context.insert(hi)

        // Study plan + reminders.
        let plan = StudyPlan()
        plan.title = "本周学习计划"; plan.targetMinutesPerDay = 25
        plan.knowledgePointIDs = ["math.equation", "math.geometry.area", "phy.force"]
        context.insert(plan)
        let reminder = StudyReminder()
        reminder.title = "每日错题复习"; reminder.hour = 19; reminder.minute = 30
        context.insert(reminder)

        // A few activity logs for the report charts.
        for dayOffset in 0..<7 {
            let log = ActivityLog()
            log.kindRaw = "tutor"
            log.subjectRaw = Subject.math.rawValue
            log.minutes = Double(15 + (dayOffset * 3) % 20)
            log.date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            context.insert(log)
        }

        // A sample document.
        let doc = DocumentEntity()
        doc.title = "科学小论文.pdf"; doc.fileType = "pdf"; doc.pageCount = 3
        doc.parsedText = ContentCatalog.sampleEssay
        doc.summary = "这篇短文讲述了作者的理想以及为实现理想付出的努力。"
        doc.keyPoints = ["理想是成为科学家", "原因：好奇与探索", "行动：认真学习、坚持不放弃"]
        doc.outline = ["提出理想", "理由阐述", "行动计划", "总结升华"]
        context.insert(doc)
    }
}

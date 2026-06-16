//
//  CalculatorView.swift
//  豆包爱学 — Features/Calculator
//
//  科学计算器 + 公式库 — a friendly, K12-flavored calculator paired with a
//  categorized reference of common formulas.
//
//  Two tabs (segmented):
//    • 计算器: an adaptive keypad (digits, + - × ÷, parentheses, %, decimal,
//      clear, equals) that evaluates the running expression through the app's
//      existing `ArithmeticEvaluator.evaluate`. A live expression display
//      (rendered with `MathText`) shows the result, and a recent-history list
//      (persisted via @AppStorage) lets learners tap to recall an expression.
//    • 公式库: a subject-categorized list of common formulas (面积/周长/体积,
//      物理 F=ma 等), each rendered with `MathText`, tappable to either copy the
//      formula into the calculator or hand it to 问豆包 for an explanation.
//
//  No new model. History is stored as a newline-joined @AppStorage string.
//  Fully adaptive, Dark-Mode-correct (semantic colors only), and accessible
//  (every key labeled, reduced-motion respected, Dynamic Type friendly).
//
//  Contract: `struct CalculatorView: View` with a no-arg `init()`. The
//  integrator maps a new ToolKind / route → CalculatorView().
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Tabs

private enum CalcTab: String, CaseIterable, Identifiable {
    case calculator
    case formulas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calculator: "计算器"
        case .formulas: "公式库"
        }
    }

    var symbol: String {
        switch self {
        case .calculator: "plus.forward.slash.minus"
        case .formulas: "function"
        }
    }
}

// MARK: - Keypad model

/// One key on the calculator keypad. Plain value type describing its glyph and
/// the action it performs — kept `nonisolated` since it carries no UI state.
private nonisolated enum CalcKey: Hashable {
    case digit(String)
    case decimal
    case op(String)        // visible operator glyph, e.g. "×"
    case openParen
    case closeParen
    case percent
    case clear
    case delete
    case equals

    /// The glyph drawn on the key.
    var glyph: String {
        switch self {
        case .digit(let d): d
        case .decimal: "."
        case .op(let o): o
        case .openParen: "("
        case .closeParen: ")"
        case .percent: "%"
        case .clear: "AC"
        case .delete: "⌫"
        case .equals: "="
        }
    }

    /// VoiceOver label.
    var accessibilityLabel: String {
        switch self {
        case .digit(let d): "数字 \(d)"
        case .decimal: "小数点"
        case .op("+"): "加"
        case .op("-"): "减"
        case .op("×"): "乘"
        case .op("÷"): "除"
        case .op(let o): o
        case .openParen: "左括号"
        case .closeParen: "右括号"
        case .percent: "百分号"
        case .clear: "全部清除"
        case .delete: "删除"
        case .equals: "等于"
        }
    }

    /// The text appended to the expression when tapped (for character keys).
    var insertion: String {
        switch self {
        case .digit(let d): d
        case .decimal: "."
        case .op(let o): o
        case .openParen: "("
        case .closeParen: ")"
        case .percent: "%"
        default: ""
        }
    }
}

private enum CalcKeyRole {
    case number      // digits + decimal
    case function    // AC, delete, parens, percent
    case operation   // + - × ÷
    case equals
}

// MARK: - Formula reference data

/// A single formula reference entry. Pure data → `nonisolated`.
private nonisolated struct FormulaItem: Identifiable, Hashable {
    let id: String
    let name: String          // 中文名称, e.g. "圆面积"
    let latex: String         // MathText-renderable expression
    let note: String          // 说明, e.g. 变量含义
    /// A pragmatic, evaluable seed for the calculator (numbers plugged in),
    /// shown as "试一试" so tapping "代入计算器" yields a real result.
    let sample: String
}

/// A subject category grouping formulas. Pure data → `nonisolated`.
private nonisolated struct FormulaCategory: Identifiable, Hashable {
    let id: String
    let title: String         // e.g. "几何 · 面积"
    let subject: Subject
    let items: [FormulaItem]
}

private nonisolated enum FormulaLibrary {
    static let categories: [FormulaCategory] = [
        FormulaCategory(
            id: "geo_area",
            title: "几何 · 面积",
            subject: .math,
            items: [
                FormulaItem(id: "rect_area", name: "长方形面积",
                            latex: "S = a \\times b",
                            note: "a 为长，b 为宽", sample: "6 × 4"),
                FormulaItem(id: "square_area", name: "正方形面积",
                            latex: "S = a^2",
                            note: "a 为边长", sample: "5 × 5"),
                FormulaItem(id: "tri_area", name: "三角形面积",
                            latex: "S = \\frac{1}{2} \\times a \\times h",
                            note: "a 为底，h 为高", sample: "(1 ÷ 2) × 8 × 5"),
                FormulaItem(id: "circle_area", name: "圆面积",
                            latex: "S = \\pi r^2",
                            note: "r 为半径，π 取 3.14", sample: "3.14 × 4 × 4"),
                FormulaItem(id: "trap_area", name: "梯形面积",
                            latex: "S = \\frac{(a+b) \\times h}{2}",
                            note: "a、b 为上下底，h 为高", sample: "((3 + 5) × 4) ÷ 2"),
                FormulaItem(id: "parallelogram", name: "平行四边形面积",
                            latex: "S = a \\times h",
                            note: "a 为底，h 为高", sample: "7 × 4"),
            ]
        ),
        FormulaCategory(
            id: "geo_perimeter",
            title: "几何 · 周长",
            subject: .math,
            items: [
                FormulaItem(id: "rect_peri", name: "长方形周长",
                            latex: "C = (a + b) \\times 2",
                            note: "a 为长，b 为宽", sample: "(6 + 4) × 2"),
                FormulaItem(id: "square_peri", name: "正方形周长",
                            latex: "C = 4a",
                            note: "a 为边长", sample: "4 × 5"),
                FormulaItem(id: "circle_peri", name: "圆周长",
                            latex: "C = 2 \\pi r",
                            note: "r 为半径，π 取 3.14", sample: "2 × 3.14 × 4"),
            ]
        ),
        FormulaCategory(
            id: "geo_volume",
            title: "几何 · 体积与表面积",
            subject: .math,
            items: [
                FormulaItem(id: "cube_vol", name: "正方体体积",
                            latex: "V = a^3",
                            note: "a 为棱长", sample: "3 × 3 × 3"),
                FormulaItem(id: "cuboid_vol", name: "长方体体积",
                            latex: "V = a \\times b \\times c",
                            note: "长 × 宽 × 高", sample: "5 × 4 × 3"),
                FormulaItem(id: "cylinder_vol", name: "圆柱体积",
                            latex: "V = \\pi r^2 h",
                            note: "r 为底面半径，h 为高", sample: "3.14 × 2 × 2 × 5"),
                FormulaItem(id: "cube_surface", name: "正方体表面积",
                            latex: "S = 6a^2",
                            note: "a 为棱长", sample: "6 × 3 × 3"),
            ]
        ),
        FormulaCategory(
            id: "physics_motion",
            title: "物理 · 力与运动",
            subject: .physics,
            items: [
                FormulaItem(id: "newton2", name: "牛顿第二定律",
                            latex: "F = ma",
                            note: "F 合外力，m 质量，a 加速度", sample: "2 × 5"),
                FormulaItem(id: "velocity", name: "匀速直线运动速度",
                            latex: "v = \\frac{s}{t}",
                            note: "s 路程，t 时间", sample: "120 ÷ 3"),
                FormulaItem(id: "accel", name: "加速度",
                            latex: "a = \\frac{v - v_0}{t}",
                            note: "v 末速度，v₀ 初速度", sample: "(20 - 5) ÷ 3"),
                FormulaItem(id: "gravity", name: "重力",
                            latex: "G = mg",
                            note: "m 质量，g 取 9.8 N/kg", sample: "2 × 9.8"),
            ]
        ),
        FormulaCategory(
            id: "physics_energy",
            title: "物理 · 功与能",
            subject: .physics,
            items: [
                FormulaItem(id: "work", name: "功",
                            latex: "W = F \\times s",
                            note: "F 力，s 沿力方向的距离", sample: "10 × 4"),
                FormulaItem(id: "power", name: "功率",
                            latex: "P = \\frac{W}{t}",
                            note: "W 做的功，t 时间", sample: "200 ÷ 5"),
                FormulaItem(id: "kinetic", name: "动能",
                            latex: "E_k = \\frac{1}{2} m v^2",
                            note: "m 质量，v 速度", sample: "(1 ÷ 2) × 4 × 3 × 3"),
                FormulaItem(id: "density", name: "密度",
                            latex: "\\rho = \\frac{m}{V}",
                            note: "m 质量，V 体积", sample: "200 ÷ 50"),
            ]
        ),
        FormulaCategory(
            id: "physics_circuit",
            title: "物理 · 电学",
            subject: .physics,
            items: [
                FormulaItem(id: "ohm", name: "欧姆定律",
                            latex: "I = \\frac{U}{R}",
                            note: "U 电压，R 电阻", sample: "6 ÷ 3"),
                FormulaItem(id: "elec_power", name: "电功率",
                            latex: "P = UI",
                            note: "U 电压，I 电流", sample: "6 × 2"),
            ]
        ),
        FormulaCategory(
            id: "chem",
            title: "化学 · 常用关系",
            subject: .chemistry,
            items: [
                FormulaItem(id: "mole", name: "物质的量",
                            latex: "n = \\frac{m}{M}",
                            note: "m 质量(g)，M 摩尔质量(g/mol)", sample: "36 ÷ 18"),
                FormulaItem(id: "concentration", name: "溶质质量分数",
                            latex: "w = \\frac{m_{质}}{m_{液}} \\times 100\\%",
                            note: "溶质质量 ÷ 溶液质量", sample: "(20 ÷ 100) × 100"),
            ]
        ),
        FormulaCategory(
            id: "math_algebra",
            title: "数学 · 代数与运算",
            subject: .math,
            items: [
                FormulaItem(id: "quadratic", name: "求根公式",
                            latex: "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
                            note: "一元二次方程 ax²+bx+c=0", sample: "(-2 + 4) ÷ 2"),
                FormulaItem(id: "perfect_square", name: "完全平方公式",
                            latex: "(a + b)^2 = a^2 + 2ab + b^2",
                            note: "乘法公式", sample: "(3 + 2) × (3 + 2)"),
                FormulaItem(id: "diff_square", name: "平方差公式",
                            latex: "a^2 - b^2 = (a + b)(a - b)",
                            note: "乘法公式", sample: "(5 + 3) × (5 - 3)"),
                FormulaItem(id: "avg", name: "平均数",
                            latex: "\\bar{x} = \\frac{x_1 + x_2 + \\ldots + x_n}{n}",
                            note: "总和 ÷ 个数", sample: "(80 + 90 + 100) ÷ 3"),
            ]
        ),
    ]
}

// MARK: - Calculator View

struct CalculatorView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Newline-joined recent expressions, most-recent first (persisted).
    @AppStorage("calculator.history") private var historyStore: String = ""

    @State private var tab: CalcTab = .calculator
    @State private var expression: String = ""
    /// Transient banner shown after copying a formula into the calculator.
    @State private var copiedToast: String?

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    // MARK: History helpers

    private var history: [String] {
        historyStore
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private func recordHistory(_ entry: String) {
        var items = history
        items.removeAll { $0 == entry }
        items.insert(entry, at: 0)
        items = Array(items.prefix(20))
        historyStore = items.joined(separator: "\n")
    }

    private func clearHistory() {
        historyStore = ""
    }

    // MARK: Live evaluation

    /// The evaluated result of the current expression, if it is well-formed.
    private var liveResult: Double? {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return ArithmeticEvaluator.evaluate(trimmed)
    }

    private var liveResultText: String? {
        liveResult.map(ArithmeticEvaluator.format)
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            picker
            Divider().overlay(Color.dbSeparator)
            Group {
                switch tab {
                case .calculator: calculatorTab
                case .formulas: formulaTab
                }
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("计算器")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay(alignment: .bottom) { toastView }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: copiedToast)
    }

    private var picker: some View {
        Picker("视图", selection: $tab) {
            ForEach(CalcTab.allCases) { t in
                Label(t.title, systemImage: t.symbol).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DBSpacing.screenInset)
        .padding(.vertical, DBSpacing.sm)
        .background(Color.dbBackground)
    }

    // MARK: - 计算器 tab

    private var calculatorTab: some View {
        VStack(spacing: DBSpacing.md) {
            displayPanel
            if !history.isEmpty {
                historyStrip
            }
            Spacer(minLength: 0)
            keypad
        }
        .padding(.horizontal, DBSpacing.screenInset)
        .padding(.top, DBSpacing.md)
        .padding(.bottom, DBSpacing.lg)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var displayPanel: some View {
        DBCard {
            VStack(alignment: .trailing, spacing: DBSpacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Group {
                        if expression.isEmpty {
                            Text("0")
                                .font(.dbTitle)
                                .foregroundStyle(Color.dbTextTertiary)
                        } else {
                            MathText(expression, font: .dbTitle)
                                .foregroundStyle(Color.dbTextPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .defaultScrollAnchor(.trailing)

                HStack(spacing: DBSpacing.sm) {
                    Spacer(minLength: 0)
                    Image(systemName: "equal")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextTertiary)
                    Text(liveResultText ?? "—")
                        .font(.dbTitle2)
                        .foregroundStyle(liveResultText == nil ? Color.dbTextTertiary : Color.dbPrimary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("算式")
        .accessibilityValue(displayAccessibilityValue)
    }

    private var displayAccessibilityValue: String {
        let expr = expression.isEmpty ? "空" : MathText.spokenLabel(from: expression)
        if let result = liveResultText {
            return "\(expr)，结果 \(result)"
        }
        return expr
    }

    private var historyStrip: some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            HStack {
                Text("最近计算")
                    .font(.dbFootnote.weight(.medium))
                    .foregroundStyle(Color.dbTextSecondary)
                Spacer()
                Button("清空") { clearHistory() }
                    .font(.dbFootnote)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.dbPrimary)
                    .accessibilityLabel("清空历史记录")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    ForEach(history, id: \.self) { entry in
                        Button {
                            HapticEngine.play(.selection)
                            expression = expressionPart(of: entry)
                        } label: {
                            Text(entry)
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, DBSpacing.md)
                                .padding(.vertical, DBSpacing.xs)
                                .background(Color.dbSurfaceRaised,
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("历史记录 \(MathText.spokenLabel(from: entry))，点按重新计算")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    /// Extract just the expression (before "=") from a stored "a+b=c" entry.
    private func expressionPart(of entry: String) -> String {
        if let eq = entry.firstIndex(of: "=") {
            return String(entry[entry.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
        }
        return entry
    }

    // MARK: Keypad

    /// Five columns on regular width, four on compact.
    private var keypadColumns: Int { isRegular ? 5 : 4 }

    /// Keypad rows. On compact (4-col) layout, the function keys sit in a top
    /// row; on regular (5-col) layout they share rows with a side column.
    private var keypadRows: [[CalcKey]] {
        [
            [.clear, .openParen, .closeParen, .percent, .delete],
            [.digit("7"), .digit("8"), .digit("9"), .op("÷"), .op("×")],
            [.digit("4"), .digit("5"), .digit("6"), .op("-"), .op("+")],
            [.digit("1"), .digit("2"), .digit("3"), .decimal, .equals],
            [.digit("0")],
        ]
    }

    /// Compact (4-column) keypad — function row collapses, operators stack.
    private var keypadRowsCompact: [[CalcKey]] {
        [
            [.clear, .openParen, .closeParen, .delete],
            [.digit("7"), .digit("8"), .digit("9"), .op("÷")],
            [.digit("4"), .digit("5"), .digit("6"), .op("×")],
            [.digit("1"), .digit("2"), .digit("3"), .op("-")],
            [.percent, .digit("0"), .decimal, .op("+")],
            [.equals],
        ]
    }

    private var keypad: some View {
        let rows = isRegular ? keypadRows : keypadRowsCompact
        return VStack(spacing: DBSpacing.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: DBSpacing.sm) {
                    ForEach(row, id: \.self) { key in
                        // A lone key in a single-element row (0 or =) spans full width.
                        keyButton(key, wide: row.count == 1)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: CalcKey, wide: Bool) -> some View {
        Button {
            handle(key)
        } label: {
            Text(key.glyph)
                .font(keyFont(for: key))
                .foregroundStyle(keyForeground(for: key))
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(keyBackground(for: key),
                           in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: wide ? .infinity : nil)
        .accessibilityLabel(key.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private func keyFont(for key: CalcKey) -> Font {
        switch roleOf(key) {
        case .number: .dbTitle2
        case .operation, .equals: .dbTitle2
        case .function: .dbTitle3
        }
    }

    private func keyForeground(for key: CalcKey) -> Color {
        switch roleOf(key) {
        case .number: .dbTextPrimary
        case .function: .dbTextSecondary
        case .operation: .dbPrimary
        case .equals: .dbOnPrimary
        }
    }

    private func keyBackground(for key: CalcKey) -> Color {
        switch roleOf(key) {
        case .number: .dbSurfaceRaised
        case .function: .dbBackgroundAlt
        case .operation: .dbPrimarySoft
        case .equals: .dbPrimary
        }
    }

    private func roleOf(_ key: CalcKey) -> CalcKeyRole {
        switch key {
        case .digit, .decimal: .number
        case .op: .operation
        case .equals: .equals
        case .openParen, .closeParen, .percent, .clear, .delete: .function
        }
    }

    // MARK: Key handling

    private func handle(_ key: CalcKey) {
        switch key {
        case .clear:
            HapticEngine.play(.light)
            expression = ""
        case .delete:
            HapticEngine.play(.selection)
            if !expression.isEmpty { expression.removeLast() }
        case .equals:
            commitEquals()
        default:
            HapticEngine.play(.selection)
            expression += key.insertion
        }
    }

    private func commitEquals() {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let value = ArithmeticEvaluator.evaluate(trimmed) {
            HapticEngine.play(.success)
            let resultText = ArithmeticEvaluator.format(value)
            recordHistory("\(trimmed) = \(resultText)")
            expression = resultText
        } else {
            HapticEngine.play(.error)
        }
    }

    // MARK: - 公式库 tab

    private var formulaTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                ForEach(FormulaLibrary.categories) { category in
                    formulaCategorySection(category)
                }
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.top, DBSpacing.md)
            .padding(.bottom, DBSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
    }

    private func formulaCategorySection(_ category: FormulaCategory) -> some View {
        let tint = DBSubjectColor.color(for: category.subject)
        return VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                category.title,
                systemImage: category.subject.symbolName
            )
            VStack(spacing: DBSpacing.md) {
                ForEach(category.items) { item in
                    formulaCard(item, tint: tint)
                }
            }
        }
    }

    private func formulaCard(_ item: FormulaItem, tint: Color) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    Text(item.name)
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Spacer(minLength: 0)
                }

                MathText(item.latex, font: .dbTitle3)
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.note)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DBSpacing.sm) {
                    Button {
                        useInCalculator(item)
                    } label: {
                        Label("代入计算器", systemImage: "plus.forward.slash.minus")
                            .font(.dbFootnote.weight(.medium))
                    }
                    .buttonStyle(.db(.secondary))

                    Button {
                        askDoubao(item)
                    } label: {
                        Label("问豆包", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.dbFootnote.weight(.medium))
                    }
                    .buttonStyle(.db(.ghost))

                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.name)，\(MathText.spokenLabel(from: item.latex))。\(item.note)")
    }

    // MARK: Formula actions

    /// Drop a runnable sample of the formula into the calculator tab.
    private func useInCalculator(_ item: FormulaItem) {
        HapticEngine.play(.selection)
        expression = item.sample
        tab = .calculator
        showToast("已代入 “\(item.name)” 示例，按 = 计算")
    }

    /// Copy the formula to the system pasteboard and open 问豆包 so the learner
    /// can paste it and ask for an explanation. (Router has no prefill seam, so
    /// we use the pasteboard — works on both platforms.)
    private func askDoubao(_ item: FormulaItem) {
        HapticEngine.play(.light)
        let payload = "请讲解公式：\(item.name)  \(MathText.spokenLabel(from: item.latex))（\(item.note)）"
        copyToPasteboard(payload)
        router.openTool(.knowledgeQA, regular: isRegular)
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    // MARK: Toast

    private func showToast(_ message: String) {
        copiedToast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedToast == message { copiedToast = nil }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = copiedToast {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.dbSuccess)
                Text(toast)
                    .font(.dbFootnote.weight(.medium))
                    .foregroundStyle(Color.dbTextPrimary)
            }
            .padding(.horizontal, DBSpacing.lg)
            .padding(.vertical, DBSpacing.md)
            .background(Color.dbSurfaceRaised, in: Capsule())
            .dbShadow(.medium)
            .padding(.bottom, DBSpacing.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
        }
    }
}

// MARK: - Preview

#Preview("Calculator") {
    NavigationStack {
        CalculatorView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

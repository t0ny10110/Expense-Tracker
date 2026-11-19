import SwiftUI
import WidgetKit

private enum TrackerStyle {
    static let mint = Color(red: 0.04, green: 0.50, blue: 0.22)
    static let brightMint = Color(red: 0.67, green: 0.96, blue: 0.27)
    static let gold = Color(red: 0.98, green: 0.72, blue: 0.31)
    static let neonCyan = Color(red: 0.16, green: 0.86, blue: 0.98)
    static let neonPink = Color(red: 0.98, green: 0.25, blue: 0.57)
    static let backgroundLight = Color(red: 0.95, green: 0.93, blue: 0.98)
    static let backgroundDark = Color(red: 0.035, green: 0.035, blue: 0.09)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundDark : backgroundLight
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.09, green: 0.08, blue: 0.16) : Color(red: 1.0, green: 0.99, blue: 1.0)
    }
}

private struct CashStackMark: View {
    let size: CGFloat

    init(size: CGFloat = 40) {
        self.size = size
    }

    var body: some View {
        ZStack {
            bill(color: Color(red: 0.04, green: 0.42, blue: 0.18))
                .rotationEffect(.degrees(-16))
                .offset(x: -size * 0.10, y: size * 0.10)

            bill(color: Color(red: 0.14, green: 0.68, blue: 0.29))
                .rotationEffect(.degrees(12))
                .offset(x: size * 0.08, y: -size * 0.06)

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .fill(LinearGradient(colors: [TrackerStyle.brightMint, TrackerStyle.mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .strokeBorder(TrackerStyle.neonCyan.opacity(0.8), lineWidth: max(1, size * 0.025))
                HStack {
                    Capsule().fill(TrackerStyle.gold).frame(width: max(2, size * 0.08))
                    Spacer(minLength: 0)
                    Capsule().fill(TrackerStyle.gold).frame(width: max(2, size * 0.08))
                }
                .padding(.horizontal, size * 0.10)
                Circle()
                    .fill(Color(red: 0.06, green: 0.47, blue: 0.19))
                    .frame(width: size * 0.25, height: size * 0.25)
                Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: max(1, size * 0.02))
                    .frame(width: size * 0.25, height: size * 0.25)
                Text("₹")
                    .font(.system(size: max(7, size * 0.16), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size * 0.80, height: size * 0.48)
            .rotationEffect(.degrees(-3))
            .offset(x: size * 0.02, y: size * 0.02)
        }
        .frame(width: size, height: size)
        .shadow(color: TrackerStyle.brightMint.opacity(0.22), radius: size * 0.10, x: 0, y: size * 0.04)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stack of cash")
    }

    private func bill(color: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
            .fill(color)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.62), lineWidth: max(1, size * 0.018))
            }
            .overlay {
                HStack {
                    Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: max(1, size * 0.018))
                        .frame(width: size * 0.13, height: size * 0.13)
                    Spacer(minLength: 0)
                    Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: max(1, size * 0.018))
                        .frame(width: size * 0.13, height: size * 0.13)
                }
                .padding(.horizontal, size * 0.08)
            }
            .frame(width: size * 0.78, height: size * 0.45)
    }
}

private enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food
    case transport
    case shopping
    case bills
    case health
    case entertainment
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food & Dining"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .bills: "Bills"
        case .health: "Health"
        case .entertainment: "Entertainment"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: "cup.and.saucer.fill"
        case .transport: "tram.fill"
        case .shopping: "bag.fill"
        case .bills: "bolt.fill"
        case .health: "cross.case.fill"
        case .entertainment: "ticket.fill"
        case .other: "ellipsis"
        }
    }

    var color: Color {
        switch self {
        case .food: Color(red: 0.13, green: 0.62, blue: 0.31)
        case .transport: Color(red: 0.12, green: 0.65, blue: 0.83)
        case .shopping: Color(red: 0.84, green: 0.30, blue: 0.58)
        case .bills: Color(red: 0.82, green: 0.57, blue: 0.18)
        case .health: Color(red: 0.80, green: 0.28, blue: 0.37)
        case .entertainment: Color(red: 0.48, green: 0.38, blue: 0.78)
        case .other: Color(red: 0.46, green: 0.49, blue: 0.59)
        }
    }
}

private struct ExpenseEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date
    var note: String
}

@MainActor
private final class ExpenseStore: ObservableObject {
    @Published private(set) var monthlyBudget: Double
    @Published private(set) var expenses: [ExpenseEntry]
    @Published private(set) var categoryBudgets: [String: [String: Double]]

    private let budgetKey = "personalExpense.monthlyBudget"
    private let expensesKey = "personalExpense.expenses"
    private let categoryBudgetsKey = "personalExpense.categoryBudgets"
    private let sharedDefaults: UserDefaults
    private let appGroupIdentifier = "group.com.organizationName.Expense-Tracker.shared"

    init() {
        let standardDefaults = UserDefaults.standard
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? standardDefaults
        sharedDefaults = defaults

        let resolvedBudget: Double
        if defaults.object(forKey: budgetKey) != nil {
            resolvedBudget = defaults.double(forKey: budgetKey)
        } else if standardDefaults.object(forKey: budgetKey) != nil {
            resolvedBudget = standardDefaults.double(forKey: budgetKey)
        } else {
            resolvedBudget = 20_000
        }
        monthlyBudget = resolvedBudget
        defaults.set(resolvedBudget, forKey: budgetKey)

        let savedData = defaults.data(forKey: expensesKey) ?? standardDefaults.data(forKey: expensesKey)
        if let savedData, let savedExpenses = try? JSONDecoder().decode([ExpenseEntry].self, from: savedData) {
            expenses = savedExpenses
            if defaults.data(forKey: expensesKey) == nil {
                defaults.set(savedData, forKey: expensesKey)
            }
        } else {
            expenses = []
        }

        let savedCategoryBudgets = defaults.data(forKey: categoryBudgetsKey)
            ?? standardDefaults.data(forKey: categoryBudgetsKey)
        if let savedCategoryBudgets,
           let decodedBudgets = try? JSONDecoder().decode([String: [String: Double]].self, from: savedCategoryBudgets) {
            categoryBudgets = decodedBudgets
            if defaults.data(forKey: categoryBudgetsKey) == nil {
                defaults.set(savedCategoryBudgets, forKey: categoryBudgetsKey)
            }
        } else {
            categoryBudgets = [:]
        }
    }

    func categoryLimit(for category: ExpenseCategory, month: Date) -> Double? {
        categoryBudgets[monthIdentifier(for: month)]?[category.rawValue]
    }

    func setCategoryLimit(_ amount: Double?, for category: ExpenseCategory, month: Date) {
        let monthKey = monthIdentifier(for: month)
        var limits = categoryBudgets[monthKey] ?? [:]
        if let amount, amount > 0 {
            limits[category.rawValue] = amount
        } else {
            limits.removeValue(forKey: category.rawValue)
        }

        if limits.isEmpty {
            categoryBudgets.removeValue(forKey: monthKey)
        } else {
            categoryBudgets[monthKey] = limits
        }
        persistCategoryBudgets()
    }

    private func monthIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func persistCategoryBudgets() {
        guard let data = try? JSONEncoder().encode(categoryBudgets) else { return }
        sharedDefaults.set(data, forKey: categoryBudgetsKey)
        UserDefaults.standard.set(data, forKey: categoryBudgetsKey)
    }

    func setMonthlyBudget(_ amount: Double) {
        monthlyBudget = amount
        sharedDefaults.set(amount, forKey: budgetKey)
        UserDefaults.standard.set(amount, forKey: budgetKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func save(_ expense: ExpenseEntry) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        } else {
            expenses.append(expense)
        }
        expenses.sort { $0.date > $1.date }
        persistExpenses()
    }

    func delete(_ expense: ExpenseEntry) {
        expenses.removeAll { $0.id == expense.id }
        persistExpenses()
    }

    private func persistExpenses() {
        guard let data = try? JSONEncoder().encode(expenses) else { return }
        sharedDefaults.set(data, forKey: expensesKey)
        UserDefaults.standard.set(data, forKey: expensesKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private enum DashboardSheet: Identifiable {
    case settings
    case expense(ExpenseEntry?)
    case transactions
    case categoryBudget(ExpenseCategory)

    var id: String {
        switch self {
        case .settings: "settings"
        case .expense(let expense): "expense-\(expense?.id.uuidString ?? "new")"
        case .transactions: "transactions"
        case .categoryBudget(let category): "category-budget-\(category.rawValue)"
        }
    }
}

private enum DashboardTab {
    case home
    case insights
    case categoryBudgets
}

private struct CategorySpending: Identifiable {
    let category: ExpenseCategory
    let total: Double
    let share: Double

    var id: String { category.rawValue }
}

private enum MoneyFormat {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func string(_ amount: Double) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

struct ContentView: View {
    @StateObject private var store = ExpenseStore()
    @AppStorage("personalExpense.appearance") private var appearanceMode = "dark"
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var activeSheet: DashboardSheet?
    @State private var selectedTab: DashboardTab = .home
    @State private var selectedInsightCategory: ExpenseCategory?

    private let calendar = Calendar.current

    private var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "system": nil
        default: .dark
        }
    }

    private var monthExpenses: [ExpenseEntry] {
        store.expenses
            .filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var monthSpent: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var todaySpent: Double {
        store.expenses.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private var weekSpent: Double {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return store.expenses
            .filter { $0.date >= week.start && $0.date < week.end }
            .reduce(0) { $0 + $1.amount }
    }

    private var dailyAverage: Double {
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
        let elapsedDays: Int
        if isCurrentMonth {
            elapsedDays = calendar.component(.day, from: Date())
        } else {
            elapsedDays = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 1
        }
        return monthSpent / Double(max(elapsedDays, 1))
    }

    private var progress: Double {
        guard store.monthlyBudget > 0 else { return 0 }
        return min(max(monthSpent / store.monthlyBudget, 0), 1)
    }

    private var usedPercentage: Int {
        guard store.monthlyBudget > 0 else { return 0 }
        return Int((monthSpent / store.monthlyBudget * 100).rounded())
    }

    private var remainingBalance: Double {
        store.monthlyBudget - monthSpent
    }

    private var previousMonth: Date {
        calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }

    private var previousMonthSpent: Double {
        store.expenses
            .filter { calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthChange: Double? {
        guard previousMonthSpent > 0 else { return nil }
        return (monthSpent - previousMonthSpent) / previousMonthSpent * 100
    }

    private var monthChangeCaption: String {
        guard let monthChange else { return "No comparison yet" }
        let monthName = previousMonth.formatted(.dateTime.month(.wide))
        if abs(monthChange) < 0.5 { return "Same as \(monthName)" }
        let amount = Int(abs(monthChange).rounded())
        return "\(amount)% \(monthChange < 0 ? "less" : "more") than \(monthName)"
    }

    private var monthChangeSymbol: String {
        guard let monthChange else { return "chart.bar" }
        if monthChange < -0.5 { return "arrow.down" }
        if monthChange > 0.5 { return "arrow.up" }
        return "equal"
    }

    private var categorySpendings: [CategorySpending] {
        ExpenseCategory.allCases.compactMap { category in
            let total = monthExpenses
                .filter { $0.category == category }
                .reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return CategorySpending(category: category, total: total, share: monthSpent > 0 ? total / monthSpent : 0)
        }
        .sorted {
            if $0.total == $1.total { return $0.category.title < $1.category.title }
            return $0.total > $1.total
        }
    }

    private var displayedInsightCategory: ExpenseCategory? {
        if let selectedInsightCategory,
           categorySpendings.contains(where: { $0.category == selectedInsightCategory }) {
            return selectedInsightCategory
        }
        return categorySpendings.first?.category
    }

    private var selectedCategoryExpenses: [ExpenseEntry] {
        guard let displayedInsightCategory else { return [] }
        return monthExpenses.filter { $0.category == displayedInsightCategory }
    }

    private var totalCategoryLimits: Double {
        ExpenseCategory.allCases.reduce(0) { total, category in
            total + (store.categoryLimit(for: category, month: selectedMonth) ?? 0)
        }
    }

    private var remainingAcrossCategoryLimits: Double {
        ExpenseCategory.allCases.reduce(0) { total, category in
            guard let limit = store.categoryLimit(for: category, month: selectedMonth) else { return total }
            return total + limit - categorySpending(for: category)
        }
    }

    private func categorySpending(for category: ExpenseCategory) -> Double {
        monthExpenses
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            TrackerStyle.background(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 23) {
                    if selectedTab == .home {
                        header
                        monthSelector
                        budgetCard
                        metricsCard
                        recentActivity
                    } else if selectedTab == .insights {
                        insightsHeader
                        monthSelector
                        insightsSummaryCard
                        categorySection
                        selectedCategoryActivity
                    } else {
                        categoryBudgetsHeader
                        monthSelector
                        categoryBudgetSummaryCard
                        categoryBudgetList
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .sheet(item: $activeSheet) { destination in
            Group {
                switch destination {
                case .settings:
                    BudgetAndAppearanceSheet(
                        budget: store.monthlyBudget,
                        appearanceMode: $appearanceMode,
                        onSaveBudget: store.setMonthlyBudget
                    )
                case .expense(let expense):
                    ExpenseEditorSheet(expense: expense, onSave: store.save)
                case .transactions:
                    TransactionsSheet(
                        month: selectedMonth,
                        expenses: monthExpenses,
                        onSave: store.save,
                        onDelete: store.delete
                    )
                case .categoryBudget(let category):
                    CategoryBudgetEditorSheet(
                        category: category,
                        currentLimit: store.categoryLimit(for: category, month: selectedMonth),
                        onSave: { store.setCategoryLimit($0, for: category, month: selectedMonth) },
                        onRemove: { store.setCategoryLimit(nil, for: category, month: selectedMonth) }
                    )
                }
            }
            .tint(TrackerStyle.mint)
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(preferredScheme)
        .tint(TrackerStyle.mint)
        .animation(.snappy(duration: 0.25), value: selectedMonth)
        .animation(.snappy(duration: 0.25), value: selectedTab)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(monthSpent > store.monthlyBudget ? "Cash is getting tight" : "You're stacking cash")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    CashStackMark(size: 30)
                }

                Text("Make every move count.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.09 : 0.65)))
            }
            .accessibilityLabel("Budget and appearance settings")
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = calendar.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        if hour < 17 { return "Good afternoon," }
        return "Good evening,"
    }

    private var monthSelector: some View {
        HStack(spacing: 0) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 48, height: 42)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")

            Spacer(minLength: 4)

            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 4)

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 48, height: 42)
                    .contentShape(Rectangle())
            }
            .disabled(calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            .opacity(calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) ? 0.35 : 1)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.75 : 0.72), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(colorScheme == .dark ? 0.06 : 0.75)))
        .frame(maxWidth: 250)
    }

    private func changeMonth(by amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: selectedMonth) else { return }
        selectedMonth = next
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CASH LEFT THIS MONTH")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)

                    Text(MoneyFormat.string(remainingBalance))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .tracking(-1.6)
                        .foregroundStyle(TrackerStyle.mint)
                        .minimumScaleFactor(0.66)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 4)

                VStack(spacing: 5) {
                    if monthSpent > store.monthlyBudget {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(TrackerStyle.neonPink)
                            .frame(width: 42, height: 42)
                            .background(TrackerStyle.neonPink.opacity(0.14), in: Circle())
                    } else {
                        CashStackMark(size: 46)
                    }

                    Text("\(usedPercentage)%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("used")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 56)
                .padding(.top, 2)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(TrackerStyle.mint.opacity(colorScheme == .dark ? 0.19 : 0.13))
                    Capsule()
                        .fill(LinearGradient(colors: [TrackerStyle.mint, TrackerStyle.brightMint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 11)
            .accessibilityElement()
            .accessibilityLabel("Monthly budget used")
            .accessibilityValue("\(usedPercentage) percent")

            HStack(alignment: .firstTextBaseline) {
                (Text(MoneyFormat.string(monthSpent)).fontWeight(.bold) + Text(" spent").foregroundColor(.secondary))
                Spacer()
                (Text(MoneyFormat.string(store.monthlyBudget)).fontWeight(.bold) + Text(" budget").foregroundColor(.secondary))
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 21)
        .padding(.vertical, 20)
        .background {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.025, green: 0.22, blue: 0.15), Color(red: 0.10, green: 0.055, blue: 0.23)]
                    : [Color(red: 0.86, green: 0.98, blue: 0.84), Color(red: 0.94, green: 0.87, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.8)))
        .shadow(color: TrackerStyle.mint.opacity(colorScheme == .dark ? 0.08 : 0.09), radius: 20, x: 0, y: 9)
    }

    private var metricsCard: some View {
        let metrics = [
            DashboardMetric(title: "TODAY", value: MoneyFormat.string(todaySpent)),
            DashboardMetric(title: "THIS WEEK", value: MoneyFormat.string(weekSpent)),
            DashboardMetric(title: "TRANSACTIONS", value: "\(monthExpenses.count)"),
            DashboardMetric(title: "DAILY AVG", value: MoneyFormat.string(dailyAverage))
        ]

        return HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.title) { index, metric in
                MetricTile(metric: metric)
                if index < metrics.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1, height: 38)
                        .padding(.horizontal, 7)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 17)
        .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.8 : 0.76), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.05 : 0.72)))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.035), radius: 18, x: 0, y: 7)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent activity")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.4)

                Spacer()

                Button {
                    activeSheet = .transactions
                } label: {
                    HStack(spacing: 5) {
                        Text("See all")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(TrackerStyle.mint)
                }
                .accessibilityLabel("See all transactions for this month")
            }

            if monthExpenses.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "tray")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(TrackerStyle.mint)
                    Text("Your month starts here")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Add an expense to see where your money goes.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 27)
                .padding(.horizontal, 20)
                .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.8 : 0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(monthExpenses.prefix(3).enumerated()), id: \.element.id) { index, expense in
                        Button {
                            activeSheet = .expense(expense)
                        } label: {
                            ExpenseRow(expense: expense, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 15)

                        if index < min(monthExpenses.count, 3) - 1 {
                            Divider().padding(.leading, 82).padding(.trailing, 16)
                        }
                    }
                }
                .padding(.vertical, 2)
                .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.8 : 0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.05 : 0.72)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.035), radius: 18, x: 0, y: 7)
            }
        }
    }

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spending insights")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text("Understand where your money went.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var insightsSummaryCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TOTAL SPENT")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.78))

                Text(MoneyFormat.string(monthSpent))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .contentTransition(.numericText())

                HStack(spacing: 9) {
                    Image(systemName: monthChangeSymbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(TrackerStyle.brightMint.opacity(0.35), in: Circle())
                    Text(monthChangeCaption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer(minLength: 0)
            insightsMiniChart
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 19)
        .frame(minHeight: 174)
        .background {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.09, green: 0.045, blue: 0.25), Color(red: 0.015, green: 0.25, blue: 0.32)]
                    : [Color(red: 0.11, green: 0.06, blue: 0.29), Color(red: 0.02, green: 0.35, blue: 0.41)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).strokeBorder(.white.opacity(0.10)))
        .shadow(color: Color(red: 0.03, green: 0.28, blue: 0.15).opacity(colorScheme == .dark ? 0.22 : 0.15), radius: 18, x: 0, y: 8)
    }

    private var insightsMiniChart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(categorySpendings.prefix(5).enumerated()), id: \.element.id) { index, spending in
                Capsule()
                    .fill(index == 0 ? TrackerStyle.brightMint : Color.white.opacity(0.38))
                    .frame(width: 9, height: max(12, CGFloat(spending.share) * 82))
            }
        }
        .frame(width: 82, height: 76, alignment: .bottomTrailing)
        .accessibilityHidden(true)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("By category")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(-0.4)

            if categorySpendings.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(TrackerStyle.mint)
                    Text("No spending yet")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Add expenses this month to see your category breakdown.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
                .padding(.horizontal, 20)
                .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(categorySpendings.enumerated()), id: \.element.id) { index, spending in
                        Button {
                            selectedInsightCategory = spending.category
                        } label: {
                            categorySpendingRow(spending, isSelected: displayedInsightCategory == spending.category)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(spending.category.title), \(MoneyFormat.string(spending.total)), \(Int((spending.share * 100).rounded())) percent. Show transactions.")
                        .accessibilityAddTraits(displayedInsightCategory == spending.category ? .isSelected : [])

                        if index < categorySpendings.count - 1 {
                            Divider()
                                .padding(.leading, 70)
                                .padding(.trailing, 12)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.88), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.05 : 0.8)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.035), radius: 16, x: 0, y: 6)
            }
        }
    }

    private func categorySpendingRow(_ spending: CategorySpending, isSelected: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: spending.category.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(spending.category.color)
                .frame(width: 48, height: 48)
                .background(spending.category.color.opacity(colorScheme == .dark ? 0.16 : 0.10), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Text(spending.category.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Text(MoneyFormat.string(spending.total))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("\(Int((spending.share * 100).rounded()))%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TrackerStyle.mint.opacity(colorScheme == .dark ? 0.20 : 0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [TrackerStyle.mint, TrackerStyle.brightMint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * spending.share)
                    }
                }
                .frame(height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(isSelected ? TrackerStyle.mint.opacity(colorScheme == .dark ? 0.10 : 0.06) : .clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var selectedCategoryActivity: some View {
        if let category = displayedInsightCategory {
            VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.4)
                Text("Transactions")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(selectedCategoryExpenses.enumerated()), id: \.element.id) { index, expense in
                        Button {
                            activeSheet = .expense(expense)
                        } label: {
                            ExpenseRow(expense: expense, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)

                        if index < selectedCategoryExpenses.count - 1 {
                            Divider().padding(.leading, 80).padding(.trailing, 15)
                        }
                    }
                }
                .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.88), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.05 : 0.8)))
            }
        }
    }

    private var categoryBudgetsHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Category budgets")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Text("Set limits, spend mindfully.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.09 : 0.65)))
            }
            .accessibilityLabel("Budget and appearance settings")
        }
        .padding(.top, 8)
    }

    private var categoryBudgetSummaryCard: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 7) {
                Text("CATEGORY LIMITS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(MoneyFormat.string(totalCategoryLimits))
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .tracking(-1.2)
                    .foregroundStyle(TrackerStyle.mint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
                Text("set")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1, height: 67)

            VStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(TrackerStyle.mint)
                    .frame(width: 48, height: 48)
                    .background(TrackerStyle.mint.opacity(0.12), in: Circle())
                Text(MoneyFormat.string(remainingAcrossCategoryLimits))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(remainingAcrossCategoryLimits >= 0 ? TrackerStyle.mint : TrackerStyle.neonPink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .contentTransition(.numericText())
                Text("left across categories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 154)
        .background {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.025, green: 0.22, blue: 0.15), Color(red: 0.045, green: 0.14, blue: 0.12)]
                    : [Color(red: 0.89, green: 0.98, blue: 0.92), Color(red: 0.94, green: 0.99, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.8)))
        .shadow(color: TrackerStyle.mint.opacity(colorScheme == .dark ? 0.08 : 0.07), radius: 18, x: 0, y: 7)
        .accessibilityElement(children: .combine)
    }

    private var categoryBudgetList: some View {
        VStack(spacing: 11) {
            ForEach(ExpenseCategory.allCases) { category in
                CategoryBudgetRow(
                    category: category,
                    spent: categorySpending(for: category),
                    limit: store.categoryLimit(for: category, month: selectedMonth)
                ) {
                    activeSheet = .categoryBudget(category)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            bottomAction(title: "Home", symbol: "house.fill", selected: selectedTab == .home) {
                selectedTab = .home
            }
            bottomAction(title: "Insights", symbol: "chart.bar.fill", selected: selectedTab == .insights) {
                selectedTab = .insights
            }
            Button {
                activeSheet = .expense(nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(LinearGradient(colors: [TrackerStyle.mint, TrackerStyle.brightMint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: TrackerStyle.mint.opacity(0.28), radius: 12, x: 0, y: 7)
            }
            .accessibilityLabel("Add expense")
            bottomAction(title: "Budgets", symbol: "slider.horizontal.3", selected: selectedTab == .categoryBudgets) {
                selectedTab = .categoryBudgets
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 76)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.78)))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.07), radius: 18, x: 0, y: 5)
        .padding(.horizontal, 24)
        .padding(.top, 7)
        .padding(.bottom, 7)
    }

    private func bottomAction(title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? TrackerStyle.mint : Color.secondary)
            .frame(width: 54, height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryBudgetRow: View {
    let category: ExpenseCategory
    let spent: Double
    let limit: Double?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard let limit, limit > 0 else { return 0 }
        return min(max(spent / limit, 0), 1)
    }

    private var statusLabel: String? {
        guard let limit else { return nil }
        if spent > limit { return "Over limit" }
        if spent >= limit { return "At limit" }
        if progress >= 0.8 { return "Near limit" }
        return nil
    }

    private var remainingText: String {
        guard let limit else { return "Set limit" }
        if spent > limit { return "Over by \(MoneyFormat.string(spent - limit))" }
        return "\(MoneyFormat.string(limit - spent)) left"
    }

    private var statusColor: Color {
        guard let limit else { return TrackerStyle.mint }
        if spent > limit { return TrackerStyle.neonPink }
        if progress >= 0.8 { return TrackerStyle.gold }
        return TrackerStyle.mint
    }

    private var accessibilitySummary: String {
        guard let limit else {
            return "Spent \(MoneyFormat.string(spent)); no limit set."
        }
        return "Spent \(MoneyFormat.string(spent)) of \(MoneyFormat.string(limit)); \(remainingText). \(statusLabel ?? "Within limit")."
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(category.color)
                    .frame(width: 54, height: 54)
                    .background(category.color.opacity(colorScheme == .dark ? 0.17 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Text(category.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 2)
                        if let statusLabel {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(statusLabel)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(statusColor)
                                Text(remainingText)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(statusColor.opacity(0.9))
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .fixedSize(horizontal: true, vertical: false)
                        } else {
                            Text(remainingText)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(statusColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    if let limit {
                        HStack(spacing: 4) {
                            Text(MoneyFormat.string(spent))
                                .fontWeight(.semibold)
                            Text("/")
                                .foregroundStyle(.secondary)
                            Text(MoneyFormat.string(limit))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(TrackerStyle.mint.opacity(colorScheme == .dark ? 0.20 : 0.13))
                                Capsule()
                                    .fill(statusColor)
                                    .frame(width: geometry.size.width * progress)
                            }
                        }
                        .frame(height: 8)
                        .accessibilityHidden(true)
                    } else {
                        HStack(spacing: 4) {
                            Text(MoneyFormat.string(spent))
                                .fontWeight(.semibold)
                            Text("spent · No limit")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(TrackerStyle.card(for: colorScheme).opacity(colorScheme == .dark ? 0.92 : 0.88), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.05 : 0.8)))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.08 : 0.035), radius: 16, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.title)
        .accessibilityValue(accessibilitySummary)
        .accessibilityHint("Set or edit this category's monthly limit")
    }
}

private struct CategoryBudgetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let category: ExpenseCategory
    let currentLimit: Double?
    let onSave: (Double) -> Void
    let onRemove: () -> Void

    @State private var amountText: String

    init(category: ExpenseCategory, currentLimit: Double?, onSave: @escaping (Double) -> Void, onRemove: @escaping () -> Void) {
        self.category = category
        self.currentLimit = currentLimit
        self.onSave = onSave
        self.onRemove = onRemove
        _amountText = State(initialValue: currentLimit.map {
            $0 == $0.rounded() ? String(Int($0)) : String($0)
        } ?? "")
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("MONTHLY LIMIT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("₹")
                        .font(.system(size: 35, weight: .medium, design: .rounded))
                        .foregroundStyle(TrackerStyle.mint)
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .accessibilityLabel("Monthly category limit in rupees")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("This limit is saved for the selected month and does not change your overall monthly budget.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                if currentLimit != nil {
                    Button(role: .destructive) {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Remove limit", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .background(TrackerStyle.background(for: colorScheme))
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = parsedAmount, amount > 0 {
                            onSave(amount)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled((parsedAmount ?? 0) <= 0)
                }
            }
        }
    }
}

private struct DashboardMetric: Identifiable {
    var title: String
    var value: String
    var id: String { title }
}

private struct MetricTile: View {
    let metric: DashboardMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.35)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(metric.value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExpenseRow: View {
    let expense: ExpenseEntry
    var showsChevron = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: expense.category.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(expense.category.color)
                .frame(width: 56, height: 56)
                .background(expense.category.color.opacity(colorScheme == .dark ? 0.16 : 0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(expenseDateText(expense.date))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(expense.category.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            Text(MoneyFormat.string(expense.amount))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 1)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private func expenseDateText(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today, \(date.formatted(date: .omitted, time: .shortened))"
    }
    if calendar.isDateInYesterday(date) {
        return "Yesterday, \(date.formatted(date: .omitted, time: .shortened))"
    }
    return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
}

private struct BudgetAndAppearanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var appearanceMode: String
    @State private var budgetText: String
    let onSaveBudget: (Double) -> Void

    init(budget: Double, appearanceMode: Binding<String>, onSaveBudget: @escaping (Double) -> Void) {
        _appearanceMode = appearanceMode
        _budgetText = State(initialValue: budget == budget.rounded() ? String(Int(budget)) : String(budget))
        self.onSaveBudget = onSaveBudget
    }

    private var parsedBudget: Double? {
        Double(budgetText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text("₹")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(TrackerStyle.mint)
                        TextField("Monthly budget", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .accessibilityLabel("Monthly budget in rupees")
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("Monthly budget")
                } footer: {
                    Text("Your budget is saved on this device and used for each month's dashboard.")
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("App appearance")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TrackerStyle.background(for: colorScheme))
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = parsedBudget, amount > 0 {
                            onSaveBudget(amount)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled((parsedBudget ?? 0) <= 0)
                }
            }
        }
        .preferredColorScheme(appearanceMode == "system" ? nil : (appearanceMode == "dark" ? .dark : .light))
    }
}

private struct ExpenseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let expense: ExpenseEntry?
    let onSave: (ExpenseEntry) -> Void

    @State private var title: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String

    init(expense: ExpenseEntry?, onSave: @escaping (ExpenseEntry) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _title = State(initialValue: expense?.title ?? "")
        _amountText = State(initialValue: expense.map { $0.amount == $0.amount.rounded() ? String(Int($0.amount)) : String($0.amount) } ?? "")
        _category = State(initialValue: expense?.category ?? .food)
        _date = State(initialValue: expense?.date ?? Date())
        _note = State(initialValue: expense?.note ?? "")
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    amountEntry
                    titleEntry
                    categoryPicker
                    dateEntry
                    noteEntry
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(TrackerStyle.background(for: colorScheme))
            .navigationTitle(expense == nil ? "Add expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var amountEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AMOUNT")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("₹")
                    .font(.system(size: 35, weight: .medium, design: .rounded))
                    .foregroundStyle(TrackerStyle.mint)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(-1.2)
                    .accessibilityLabel("Expense amount in rupees")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var titleEntry: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("WHAT WAS IT FOR?")
            TextField("e.g. Coffee with friends", text: $title)
                .font(.system(size: 16, weight: .medium))
                .padding(16)
                .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Expense title")
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("CATEGORY")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(ExpenseCategory.allCases) { item in
                    Button {
                        category = item
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(item.color)
                                .frame(width: 25)
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                            if category == item {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(TrackerStyle.mint)
                            }
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 47)
                        .background(category == item ? TrackerStyle.mint.opacity(0.11) : TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(category == item ? TrackerStyle.mint.opacity(0.45) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(category == item ? .isSelected : [])
                }
            }
        }
    }

    private var dateEntry: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("DATE")
            DatePicker("Expense date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var noteEntry: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("NOTE · OPTIONAL")
            TextField("Add a little detail", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 15))
                .padding(15)
                .background(TrackerStyle.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Optional note")
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    private func saveExpense() {
        guard let amount = parsedAmount, amount > 0 else { return }
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ExpenseEntry(
            id: expense?.id ?? UUID(),
            title: cleanedTitle,
            amount: amount,
            category: category,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(entry)
        dismiss()
    }
}

private struct TransactionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingExpense: ExpenseEntry?

    let month: Date
    let expenses: [ExpenseEntry]
    let onSave: (ExpenseEntry) -> Void
    let onDelete: (ExpenseEntry) -> Void

    private var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "No expenses yet",
                        systemImage: "tray",
                        description: Text("Expenses you add for this month will appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(expenses) { expense in
                            Button {
                                editingExpense = expense
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(TrackerStyle.card(for: colorScheme))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(expense)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingExpense = expense
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(TrackerStyle.mint)
                            }
                        }
                    } header: {
                        HStack {
                            Text("MONTH TOTAL")
                            Spacer()
                            Text(MoneyFormat.string(total))
                                .foregroundStyle(.primary)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TrackerStyle.background(for: colorScheme))
            .navigationTitle(month.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseEditorSheet(expense: expense, onSave: onSave)
                .tint(TrackerStyle.mint)
                .presentationDragIndicator(.visible)
        }
    }
}

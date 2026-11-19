import SwiftUI
import WidgetKit

private enum TrackerStyle {
    static let mint = Color(red: 0.04, green: 0.61, blue: 0.43)
    static let brightMint = Color(red: 0.20, green: 0.82, blue: 0.62)
    static let backgroundLight = Color(red: 0.965, green: 0.965, blue: 0.95)
    static let backgroundDark = Color(red: 0.055, green: 0.075, blue: 0.073)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundDark : backgroundLight
    }

    static func card(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.105, green: 0.13, blue: 0.125) : .white
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
        case .food: Color(red: 0.08, green: 0.65, blue: 0.47)
        case .transport: Color(red: 0.20, green: 0.52, blue: 0.83)
        case .shopping: Color(red: 0.60, green: 0.42, blue: 0.82)
        case .bills: Color(red: 0.91, green: 0.59, blue: 0.20)
        case .health: Color(red: 0.90, green: 0.36, blue: 0.40)
        case .entertainment: Color(red: 0.88, green: 0.46, blue: 0.28)
        case .other: Color(red: 0.48, green: 0.55, blue: 0.58)
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

    private let budgetKey = "personalExpense.monthlyBudget"
    private let expensesKey = "personalExpense.expenses"
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

    var id: String {
        switch self {
        case .settings: "settings"
        case .expense(let expense): "expense-\(expense?.id.uuidString ?? "new")"
        case .transactions: "transactions"
        }
    }
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

    var body: some View {
        ZStack {
            TrackerStyle.background(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 23) {
                    header
                    monthSelector
                    budgetCard
                    metricsCard
                    recentActivity
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
                }
            }
            .tint(TrackerStyle.mint)
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(preferredScheme)
        .tint(TrackerStyle.mint)
        .animation(.snappy(duration: 0.25), value: selectedMonth)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(monthSpent > store.monthlyBudget ? "A little over budget" : "You're on track")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("🌱")
                        .font(.system(size: 26))
                }

                Text("Small steps make a big future.")
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
                    Text("LEFT THIS MONTH")
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
                    Image(systemName: monthSpent > store.monthlyBudget ? "exclamationmark" : "leaf.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(TrackerStyle.mint)
                        .frame(width: 42, height: 42)
                        .background(TrackerStyle.mint.opacity(0.12), in: Circle())

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
                    ? [Color(red: 0.09, green: 0.24, blue: 0.19), Color(red: 0.10, green: 0.17, blue: 0.15)]
                    : [Color(red: 0.88, green: 0.97, blue: 0.91), Color(red: 0.92, green: 0.98, blue: 0.94)],
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

    private var bottomBar: some View {
        HStack(spacing: 0) {
            bottomAction(title: "Home", symbol: "house.fill", selected: true) { }
            Spacer(minLength: 8)
            Button {
                activeSheet = .expense(nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(LinearGradient(colors: [TrackerStyle.mint, TrackerStyle.brightMint], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: TrackerStyle.mint.opacity(0.28), radius: 12, x: 0, y: 7)
            }
            .accessibilityLabel("Add expense")
            Spacer(minLength: 8)
            bottomAction(title: "Activity", symbol: "list.bullet", selected: false) {
                activeSheet = .transactions
            }
        }
        .padding(.horizontal, 28)
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
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? TrackerStyle.mint : Color.secondary)
            .frame(width: 64, height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

import WidgetKit
import SwiftUI

private struct WidgetExpense: Decodable {
    let amount: Double
    let date: Date
}

private enum WidgetExpenseData {
    static let appGroupIdentifier = "group.com.organizationName.Expense-Tracker.shared"
    static let budgetKey = "personalExpense.monthlyBudget"
    static let expensesKey = "personalExpense.expenses"

    static func entry(at date: Date) -> Expense_TrackerWidgetExtensionEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let budget = defaults?.object(forKey: budgetKey) == nil
            ? 20_000
            : defaults?.double(forKey: budgetKey) ?? 20_000

        let expenses: [WidgetExpense]
        if let data = defaults?.data(forKey: expensesKey),
           let savedExpenses = try? JSONDecoder().decode([WidgetExpense].self, from: data) {
            expenses = savedExpenses
        } else {
            expenses = []
        }

        let calendar = Calendar.current
        let monthlyExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
        let todayExpenses = expenses.filter { calendar.isDate($0.date, inSameDayAs: date) }

        return Expense_TrackerWidgetExtensionEntry(
            date: date,
            budget: budget,
            spent: monthlyExpenses.reduce(0) { $0 + $1.amount },
            todaySpent: todayExpenses.reduce(0) { $0 + $1.amount }
        )
    }
}

struct Expense_TrackerWidgetExtensionEntry: TimelineEntry {
    let date: Date
    let budget: Double
    let spent: Double
    let todaySpent: Double

    var remaining: Double { budget - spent }
    var progress: Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }
}

struct Expense_TrackerWidgetExtensionProvider: TimelineProvider {
    func placeholder(in context: Context) -> Expense_TrackerWidgetExtensionEntry {
        Expense_TrackerWidgetExtensionEntry(date: Date(), budget: 20_000, spent: 7_500, todaySpent: 850)
    }

    func getSnapshot(in context: Context, completion: @escaping (Expense_TrackerWidgetExtensionEntry) -> Void) {
        completion(WidgetExpenseData.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Expense_TrackerWidgetExtensionEntry>) -> Void) {
        let now = Date()
        let entry = WidgetExpenseData.entry(at: now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }
}

private enum WidgetPalette {
    static let mint = Color(red: 0.04, green: 0.61, blue: 0.43)
    static let brightMint = Color(red: 0.20, green: 0.82, blue: 0.62)

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.10, blue: 0.095)
            : Color(red: 0.97, green: 0.98, blue: 0.96)
    }
}

private enum WidgetMoneyFormat {
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

struct Expense_TrackerWidgetExtensionEntryView: View {
    var entry: Expense_TrackerWidgetExtensionProvider.Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if family == .systemSmall {
                smallWidget
            } else {
                mediumWidget
            }
        }
        .containerBackground(for: .widget) {
            WidgetPalette.background(for: colorScheme)
        }
        .widgetURL(URL(string: "expensetracker://dashboard"))
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetPalette.mint)
                Text("THIS MONTH")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Text(WidgetMoneyFormat.string(entry.remaining))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
            Text("left to spend")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, -5)

            progressBar
                .padding(.top, 2)

            HStack(spacing: 3) {
                Text("Spent")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text("\(WidgetMoneyFormat.string(entry.spent)) / \(WidgetMoneyFormat.string(entry.budget))")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.mint)
                Text("Today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(WidgetMoneyFormat.string(entry.todaySpent))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(13)
    }

    private var mediumWidget: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetPalette.mint)
                    Text("LEFT THIS MONTH")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.65)
                        .foregroundStyle(.secondary)
                }

                Text(WidgetMoneyFormat.string(entry.remaining))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())

                progressBar
                    .padding(.top, 1)

                HStack(spacing: 4) {
                    Text("Spent")
                        .foregroundStyle(.secondary)
                    Text(WidgetMoneyFormat.string(entry.spent))
                        .fontWeight(.semibold)
                    Spacer(minLength: 4)
                    Text("Budget")
                        .foregroundStyle(.secondary)
                    Text(WidgetMoneyFormat.string(entry.budget))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetPalette.mint)
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Text(WidgetMoneyFormat.string(entry.todaySpent))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("spent so far")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 92)
            .frame(maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .background(WidgetPalette.mint.opacity(colorScheme == .dark ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(15)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetPalette.mint.opacity(colorScheme == .dark ? 0.20 : 0.14))
                Capsule()
                    .fill(LinearGradient(colors: [WidgetPalette.mint, WidgetPalette.brightMint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * entry.progress)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(Int((entry.progress * 100).rounded())) percent of monthly budget spent")
    }
}

struct Expense_TrackerWidgetExtensionWidget: Widget {
    let kind: String = "com.organizationName.Expense-Tracker.expensetrackerwidgetextension.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Expense_TrackerWidgetExtensionProvider()) { entry in
            Expense_TrackerWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Monthly Budget")
        .description("See your remaining budget, spending progress, and today's total.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct Expense_TrackerWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        Expense_TrackerWidgetExtensionWidget()
    }
}

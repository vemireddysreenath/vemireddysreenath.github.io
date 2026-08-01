import AppIntents
import PulseBoardShared

@MainActor
struct TodayCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Calories Burned Today"
    static var description = IntentDescription("Reports your total calories burned so far today, from HealthKit.")

    @Dependency private var healthStore: HealthStore

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        async let active = healthStore.todaysActiveCalories()
        async let basal = healthStore.todaysBasalCalories()
        let (activeValue, basalValue) = await (active, basal)
        let total = Int((activeValue + basalValue).rounded())

        return .result(
            dialog: IntentDialog("You've burned \(total) calories today."),
            view: StatSnippetView(
                title: "Calories Today",
                value: "\(total) cal",
                subtitle: "Active: \(Int(activeValue.rounded())) cal",
                systemImage: "flame.fill"
            )
        )
    }
}

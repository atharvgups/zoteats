import SwiftUI
import ZotEatsKit

// Detail sheet for a single dish — nutrition stats, dietary tags,
// allergen warnings, and a favorite toggle.

struct DishDetailSheet: View {
    let dish: MenuItem
    let prefs: Preferences
    var plate: PlateStore?

    @Environment(\.dismiss) private var dismiss

    private var isFavorite: Bool {
        prefs.isFavorite(dish.name)
    }

    private var isOnPlate: Bool {
        plate?.isOnPlate(dish.name) ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                statsRow

                if let facts = dish.nutrition, facts.hasMacros {
                    macroRow(facts)
                }

                if !dish.dietaryTags.isEmpty {
                    tagSection(
                        title: "Dietary",
                        icon: "leaf.fill",
                        tint: .green
                    ) {
                        ForEach(dish.dietaryTags, id: \.self) { tag in
                            TagChip(text: tag, color: TagPalette.dietColor(tag))
                        }
                    }
                }

                if !dish.allergens.isEmpty {
                    tagSection(
                        title: "Allergens",
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange
                    ) {
                        ForEach(dish.allergens, id: \.self) { allergen in
                            AllergenChip(text: allergen)
                        }
                    }
                }

                if let facts = dish.nutrition {
                    NutritionDetailsCard(facts: facts)
                }

                favoriteToggle

                if let plate {
                    plateToggle(plate)
                }
            }
            .padding(20)
            .padding(.top, 8)
        }
        .background(Color.screen)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dish.name)
                .font(ZotFont.hero(28))
                .padding(.trailing, 40) // keep clear of the close button

            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "flame.fill",
                tint: .orange,
                value: dish.calories.map { "\($0)" } ?? "—",
                label: "Calories"
            )
            StatCard(
                icon: "scalemass.fill",
                tint: .uciBlue,
                value: dish.servingSize ?? "—",
                label: "Serving"
            )
        }
    }

    /// Protein / carbs / fat at a glance — the numbers people actually check.
    private func macroRow(_ facts: NutritionFacts) -> some View {
        HStack(spacing: 12) {
            MacroCard(value: facts.proteinG, label: "Protein", tint: TagPalette.sage)
            MacroCard(value: facts.totalCarbsG, label: "Carbs", tint: .uciBlue)
            MacroCard(value: facts.totalFatG, label: "Fat", tint: TagPalette.terracotta)
        }
    }

    private func tagSection(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder chips: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(ZotFont.sectionTitle)
                .foregroundStyle(tint)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: 7) {
                chips()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .zotCard()
    }

    private var favoriteToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                prefs.toggleFavorite(dish.name)
            }
        } label: {
            Label(
                isFavorite ? "Favorited" : "Add to Favorites",
                systemImage: isFavorite ? "heart.fill" : "heart"
            )
            .font(ZotFont.pill.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isFavorite ? AnyShapeStyle(Color.pink.opacity(0.15)) : AnyShapeStyle(Color.uciBlue),
                in: Capsule()
            )
            .foregroundStyle(isFavorite ? Color.pink : Color.white)
            .symbolEffect(.bounce, value: isFavorite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isFavorite ? "Remove \(dish.name) from favorites" : "Add \(dish.name) to favorites"
        )
    }

    private func plateToggle(_ plate: PlateStore) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                plate.toggle(dish)
            }
        } label: {
            Label(
                isOnPlate ? "On your plate" : "Add to My Plate",
                systemImage: isOnPlate ? "checkmark.circle.fill" : "plus.circle"
            )
            .font(ZotFont.pill.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isOnPlate ? Color.uciBlue.opacity(0.12) : Color.primary.opacity(0.05),
                in: Capsule()
            )
            .foregroundStyle(isOnPlate ? Color.uciBlue : .primary)
            .symbolEffect(.bounce, value: isOnPlate)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isOnPlate ? "Remove \(dish.name) from my plate" : "Add \(dish.name) to my plate"
        )
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary, .quaternary)
        }
        .buttonStyle(.plain)
        .padding(16)
        .accessibilityLabel("Close")
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .zotCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Macro card

private struct MacroCard: View {
    let value: Double?
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value.map { "\(Int($0.rounded()))g" } ?? "—")
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .zotCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value.map { "\(Int($0.rounded())) grams" } ?? "unknown")")
    }
}

// MARK: - Full nutrition label + ingredients (collapsed by default)

private struct NutritionDetailsCard: View {
    let facts: NutritionFacts
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack {
                    Label("Full nutrition", systemImage: "list.clipboard")
                        .font(ZotFont.sectionTitle)
                        .foregroundStyle(Color.uciBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Full nutrition, \(expanded ? "collapse" : "expand")")

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    factRow("Total fat", facts.totalFatG, unit: "g")
                    factRow("Saturated fat", facts.saturatedFatG, unit: "g", indent: true)
                    factRow("Trans fat", facts.transFatG, unit: "g", indent: true)
                    factRow("Sodium", facts.sodiumMg, unit: "mg")
                    factRow("Total carbs", facts.totalCarbsG, unit: "g")
                    factRow("Dietary fiber", facts.dietaryFiberG, unit: "g", indent: true)
                    factRow("Sugars", facts.sugarsG, unit: "g", indent: true)
                    factRow("Protein", facts.proteinG, unit: "g")

                    if let ingredients = facts.ingredients {
                        Text("Ingredients")
                            .font(ZotFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                        Text(ingredients)
                            .font(ZotFont.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                    }

                    Text("Per serving, from UCI Dining's published data.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 12)
                }
                .padding(.top, 10)
                .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zotCard()
    }

    @ViewBuilder
    private func factRow(_ name: String, _ value: Double?, unit: String, indent: Bool = false) -> some View {
        if let value {
            HStack {
                Text(name)
                    .font(indent ? ZotFont.caption : ZotFont.body)
                    .foregroundStyle(indent ? .secondary : .primary)
                    .padding(.leading, indent ? 14 : 0)
                Spacer()
                Text(unit == "mg" ? "\(Int(value.rounded()))mg" : String(format: "%.1fg", value))
                    .font(indent ? ZotFont.caption : ZotFont.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}

// MARK: - Allergen chip with warning icon

private struct AllergenChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(TagPalette.allergenColor.opacity(0.14), in: Capsule())
        .foregroundStyle(TagPalette.allergenColor)
        .accessibilityLabel("Contains \(text)")
    }
}

// MARK: - Simple wrapping flow layout for chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? max(0, x - spacing), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    DishDetailSheet(
        dish: MenuItem(
            id: "preview-dish",
            name: "Roasted Vegetable Grain Bowl",
            description: "Charred seasonal vegetables over herbed farro with lemon-tahini drizzle and toasted seeds.",
            calories: 420,
            servingSize: "1 bowl",
            allergens: ["Sesame", "Wheat"],
            dietaryTags: ["Vegan", "Halal"]
        ),
        prefs: Preferences()
    )
}

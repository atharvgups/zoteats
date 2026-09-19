import SwiftUI
import ZotEatsKit

// Detail sheet for a single dish — nutrition stats, dietary tags,
// allergen warnings, favorite toggle, and optional plate CTA.

struct DishDetailSheet: View {
    let dish: MenuItem
    let prefs: Preferences
    /// Nil when browsing a future day (plate building is today-only).
    var plate: PlateStore?

    @Environment(\.dismiss) private var dismiss

    @State private var noteDraft = ""

    private var isFavorite: Bool {
        prefs.isFavorite(dish.name)
    }

    private var isOnPlate: Bool {
        plate?.isOnPlate(dish.name) ?? false
    }

    private var hasTags: Bool {
        !dish.dietaryTags.isEmpty || !dish.allergens.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if hasTags {
                    chipBlock
                }

                statsRow

                if let facts = dish.nutrition, facts.hasMacros {
                    macroRow(facts)
                }

                if let facts = dish.nutrition, facts.hasDetails {
                    NutritionDetailsCard(facts: facts)
                }

                reviewBoard

                actionRow
            }
            .padding(20)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .appCanvas()
        .safeAreaInset(edge: .bottom) {
            if let plate {
                plateToggle(plate)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.screen)
            }
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .onAppear {
            noteDraft = prefs.review(for: dish.name)?.note ?? ""
            Task { await prefs.loadCommunityReviews() }
        }
        .onDisappear {
            if let current = prefs.review(for: dish.name), noteDraft != current.note {
                prefs.setReview(dishName: dish.name, stars: current.stars, note: noteDraft, playHaptic: false)
            }
        }
    }

    /// Always room for rating + nutrition; large when they scroll.
    private var detents: Set<PresentationDetent> {
        [.medium, .large]
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dish.name)
                .font(ZotFont.hero(26))
                .padding(.trailing, 40)

            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(ZotFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var chipBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !dish.dietaryTags.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(dish.dietaryTags, id: \.self) { tag in
                        TagChip(text: tag, color: TagPalette.dietColor(tag))
                    }
                }
            }
            if !dish.allergens.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(dish.allergens, id: \.self) { allergen in
                        AllergenChip(text: allergen)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                icon: servingIcon,
                tint: .ink,
                value: prettyServing,
                label: "Serving"
            )
        }
    }

    /// Protein / carbs / fat at a glance — the numbers people actually check.
    private func macroRow(_ facts: NutritionFacts) -> some View {
        HStack(spacing: 12) {
            MacroCard(value: facts.proteinG, label: "Protein", tint: TagPalette.sage)
            MacroCard(value: facts.totalCarbsG, label: "Carbs", tint: TagPalette.slate)
            MacroCard(value: facts.totalFatG, label: "Fat", tint: TagPalette.terracotta)
        }
    }

    /// Anteater often ships unit as "fl" for fluid ounces — show something readable.
    private var prettyServing: String {
        guard var serving = dish.servingSize, !serving.isEmpty else { return "—" }
        // "4 fl" / "6 fl" → "4 fl oz"
        if serving.range(of: #"^\d+(\.\d+)?\s*fl$"#, options: .regularExpression) != nil {
            serving = serving.replacingOccurrences(of: "fl", with: "fl oz")
        }
        return serving
    }

    private var servingIcon: String {
        let s = (dish.servingSize ?? "").lowercased()
        if s.contains("fl") || s.contains("oz") || s.contains("cup") || s.contains("ml") {
            return "cup.and.saucer.fill"
        }
        return "scalemass.fill"
    }

    private var currentReview: MealReview? {
        prefs.review(for: dish.name)
    }

    private var dishReviews: [MealReview] {
        prefs.reviewsForDish(dish.name)
    }

    private var otherReviews: [MealReview] {
        prefs.communityReviews(for: dish.name)
    }

    private var reviewBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let average = prefs.averageStars(for: dish.name) {
                HStack(spacing: 10) {
                    StarRatingControl(
                        stars: MealReviewLogic.roundedAverage(dishReviews),
                        size: 18,
                        interactive: false
                    )
                    Text(CommunityReviewCopy.averageLine(average: average, count: dishReviews.count))
                        .font(ZotFont.caption.weight(.semibold))
                        .foregroundStyle(Color.inkMuted)
                }
                .accessibilityIdentifier("dish-community-average")
            }

            Text(CommunityReviewCopy.yourRating)
                .font(ZotFont.kicker)
                .foregroundStyle(Color.inkMuted)

            StarRatingControl(stars: currentReview?.stars ?? 0, size: 22) { value in
                prefs.setReview(dishName: dish.name, stars: value, note: noteDraft)
            }
            .accessibilityIdentifier("dish-star-rating")

            if currentReview != nil {
                TextField("Add a note", text: $noteDraft, axis: .vertical)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1...2)
                    .textFieldStyle(.plain)
                    .onChange(of: noteDraft) { _, newValue in
                        guard let stars = currentReview?.stars else { return }
                        prefs.setReview(dishName: dish.name, stars: stars, note: newValue, playHaptic: false)
                    }
                    .accessibilityIdentifier("dish-review-note")

                Button("Clear") {
                    noteDraft = ""
                    prefs.clearReview(dishName: dish.name)
                }
                .font(ZotFont.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("dish-clear-rating")
            }

            Text(CommunityReviewCopy.communityHeader)
                .font(ZotFont.kicker)
                .foregroundStyle(Color.inkMuted)
                .padding(.top, 4)

            if otherReviews.isEmpty {
                Text(CommunityReviewCopy.empty)
                    .font(ZotFont.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("dish-community-empty")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(otherReviews) { review in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(review.resolvedAuthorLabel)
                                    .font(ZotFont.caption.weight(.semibold))
                                StarRatingControl(stars: review.stars, size: 12, interactive: false)
                            }
                            if !review.note.isEmpty {
                                Text(review.note)
                                    .font(ZotFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("dish-community-review")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            favoriteToggle
            if let plate {
                headerPlateButton(plate)
            }
        }
    }

    private var favoriteToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                prefs.toggleFavorite(dish.name)
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.pink : Color.secondary)
                .symbolEffect(.bounce, value: isFavorite)
                .frame(width: 44, height: 44)
                .background(
                    isFavorite ? Color.pink.opacity(0.15) : Color.primary.opacity(0.05),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isFavorite ? "Remove \(dish.name) from favorites" : "Add \(dish.name) to favorites"
        )
    }

    private func headerPlateButton(_ plate: PlateStore) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                plate.toggle(dish)
            }
            Haptics.soft()
        } label: {
            Image(systemName: isOnPlate ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOnPlate ? Color.ink : Color.inkMuted)
                .symbolEffect(.bounce, value: isOnPlate)
                .frame(width: 44, height: 44)
                .background(
                    isOnPlate ? Color.ink.opacity(0.12) : Color.primary.opacity(0.05),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isOnPlate ? "Remove \(dish.name) from my plate" : "Add \(dish.name) to my plate"
        )
        .accessibilityIdentifier("dish-add-to-plate-icon")
    }

    private func plateToggle(_ plate: PlateStore) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                plate.toggle(dish)
            }
            Haptics.soft()
        } label: {
            Label(
                isOnPlate ? "Remove from Plate" : "Add to Plate",
                systemImage: isOnPlate ? "minus.circle.fill" : "plus.circle.fill"
            )
            .font(ZotFont.pill.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isOnPlate ? AnyShapeStyle(Color.ink.opacity(0.15)) : AnyShapeStyle(Color.ink),
                in: Capsule()
            )
            .foregroundStyle(isOnPlate ? Color.ink : Color.screen)
            .symbolEffect(.bounce, value: isOnPlate)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel(
            isOnPlate ? "Remove \(dish.name) from my plate" : "Add \(dish.name) to my plate"
        )
        .accessibilityIdentifier("dish-add-to-plate")
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
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
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
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
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: ExpandChevron.systemName(isExpanded: expanded))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18, height: 18)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Full nutrition, \(expanded ? "collapse" : "expand")")
            .accessibilityIdentifier("full-nutrition-toggle")

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

                    if let ingredients = facts.ingredients, !ingredients.isEmpty {
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
                .font(ZotFont.caption.weight(.medium))
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
            dietaryTags: ["Vegan", "Halal"],
            nutrition: NutritionFacts(
                proteinG: 14,
                totalCarbsG: 52,
                totalFatG: 16,
                saturatedFatG: 2,
                transFatG: 0,
                sodiumMg: 480,
                sugarsG: 6,
                dietaryFiberG: 9,
                ingredients: "Farro, roasted vegetables, tahini, lemon, seeds."
            )
        ),
        prefs: Preferences(),
        plate: PlateStore()
    )
}

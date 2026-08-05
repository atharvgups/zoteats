import SwiftUI
import ZotEatsKit

// Detail sheet for a single dish — nutrition stats, dietary tags,
// allergen warnings, and a favorite toggle.

struct DishDetailSheet: View {
    let dish: MenuItem
    let prefs: Preferences

    @Environment(\.dismiss) private var dismiss

    private var isFavorite: Bool {
        prefs.isFavorite(dish.name)
    }

    private var hasTags: Bool {
        !dish.dietaryTags.isEmpty || !dish.allergens.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if hasTags {
                chipBlock
            }

            statsRow

            favoriteToggle
        }
        .padding(20)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.screen)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        // Fit content — medium detent left a huge empty band when tags were absent.
        .presentationDetents([.height(hasTags ? 420 : 340), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dish.name)
                .font(ZotFont.hero(26))
                .padding(.trailing, 40) // keep clear of the close button

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
                tint: .uciBlue,
                value: prettyServing,
                label: "Serving"
            )
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
            .padding(.vertical, 14)
            .background(
                isFavorite ? AnyShapeStyle(Color.pink.opacity(0.15)) : AnyShapeStyle(Color.uciBlue),
                in: Capsule()
            )
            .foregroundStyle(isFavorite ? Color.pink : Color.white)
            .symbolEffect(.bounce, value: isFavorite)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel(
            isFavorite ? "Remove \(dish.name) from favorites" : "Add \(dish.name) to favorites"
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

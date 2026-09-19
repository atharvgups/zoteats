import SwiftUI
import ZotEatsKit

// Today's plate: what you've tapped on, with the running totals up top.

struct PlateSheet: View {
    let plate: PlateStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Plate")
                        .font(ZotFont.hero(26))
                    Text("Today's picks — totals include every serving.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 44)

                HStack(spacing: 12) {
                    totalCard(
                        value: PlateTallyCopy.caloriesValue(plate.totalCalories),
                        label: "Calories",
                        tint: .orange,
                        announce: PlateTotalsAccessibility.shouldAnnounceTotals(isEmpty: plate.isEmpty)
                    )
                    totalCard(
                        value: PlateTallyCopy.proteinValue(plate.totalProteinG),
                        label: "Protein",
                        tint: TagPalette.sage,
                        announce: PlateTotalsAccessibility.shouldAnnounceTotals(isEmpty: plate.isEmpty)
                    )
                }
                .opacity(plate.isEmpty ? 0.55 : 1)
                .animation(.snappy(duration: 0.2), value: plate.totalCalories)
                .animation(.snappy(duration: 0.2), value: plate.totalProteinG)

                if plate.isEmpty {
                    VStack(spacing: 8) {
                        Text(PlateEmptyCopy.title)
                            .font(ZotFont.cardTitle)
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                        Text(PlateEmptyCopy.message)
                            .font(ZotFont.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(PlateEmptyCopy.footnote)
                            .font(ZotFont.caption.weight(.medium))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 8)
                    .accessibilityElement(children: .combine)
                } else {
                    VStack(spacing: 8) {
                        ForEach(plate.entries) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.dishName)
                                        .font(ZotFont.body.weight(.medium))
                                        .lineLimit(2)
                                    macroCaption(entry)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    PlateEntryAccessibility.label(
                                        dishName: entry.dishName,
                                        calories: entry.lineCalories,
                                        proteinG: entry.lineProteinG.map { Int($0.rounded()) },
                                        quantity: entry.quantity
                                    )
                                )

                                quantityStepper(entry)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .zotCard()
                        }
                    }

                    Button {
                        if plate.servingCount >= 2 {
                            confirmClear = true
                        } else {
                            clearPlate()
                        }
                    } label: {
                        Text("Clear plate")
                            .font(ZotFont.pill.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .accessibilityLabel("Clear plate")
                }
            }
            .padding(20)
        }
        .appCanvas()
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary, .quaternary)
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Close plate")
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Clear everything on your plate?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Clear plate", role: .destructive) {
                clearPlate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes all \(plate.servingCount) servings. This can't be undone.")
        }
    }

    private func clearPlate() {
        withAnimation(.snappy(duration: 0.25)) {
            plate.clear()
        }
        Haptics.selection()
    }

    private func quantityStepper(_ entry: PlateEntry) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    plate.decrement(entry)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove one serving of \(entry.dishName)")

            Text("\(entry.quantity)")
                .font(ZotFont.pill.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 18)
                .accessibilityLabel(
                    PlateQuantityCopy.stepperAccessibility(
                        dishName: entry.dishName,
                        quantity: entry.quantity
                    )
                )

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    plate.increment(entry)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add another serving of \(entry.dishName)")
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func macroCaption(_ entry: PlateEntry) -> some View {
        let parts: [String] = [
            entry.quantity > 1 ? "×\(entry.quantity)" : nil,
            entry.lineCalories.map { "\($0) cal" },
            entry.lineProteinG.map { "\(Int($0.rounded()))g" },
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    private func totalCard(value: String, label: String, tint: Color, announce: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(ZotFont.face(22, relativeTo: .title2).weight(.medium))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .zotCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PlateTotalsAccessibility.label(name: label, value: value))
        .accessibilityHidden(!announce)
    }
}

import SwiftUI
import ZotEatsKit

// Today's plate: what you've tapped on, with the running totals up top.

struct PlateSheet: View {
    let plate: PlateStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Plate")
                        .font(ZotFont.hero(26))
                    Text("Today's picks — totals are per standard serving.")
                        .font(ZotFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 44)

                HStack(spacing: 12) {
                    totalCard(value: "\(plate.totalCalories)", label: "Calories", tint: .orange)
                    totalCard(value: "\(plate.totalProteinG)g", label: "Protein", tint: TagPalette.sage)
                }

                if plate.isEmpty {
                    EmptyStateView(
                        icon: "fork.knife.circle",
                        title: "Nothing on your plate yet",
                        message: "Tap the + on any dish to start today's tally."
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(plate.entries) { entry in
                            HStack(spacing: 10) {
                                Text(entry.dishName)
                                    .font(ZotFont.body.weight(.medium))
                                    .lineLimit(2)
                                Spacer()
                                if let calories = entry.calories {
                                    Text("\(calories) cal")
                                        .font(ZotFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        plate.remove(entry)
                                    }
                                    Haptics.soft()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.secondary, .quaternary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(entry.dishName) from plate")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .zotCard()
                        }
                    }

                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            plate.clear()
                        }
                        Haptics.selection()
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
                }
            }
            .padding(20)
        }
        .background(Color.screen)
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
    }

    private func totalCard(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(ZotFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .zotCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

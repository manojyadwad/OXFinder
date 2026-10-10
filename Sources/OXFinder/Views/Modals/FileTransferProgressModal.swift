import SwiftUI

/// Windows 11 / File Explorer Style File Transfer Progress Dialog
public struct FileTransferProgressModal: View {
    @ObservedObject var progress: TransferProgressState
    let onCancel: () -> Void

    @State private var isDetailsExpanded: Bool = true

    public var body: some View {
        ZStack {
            // Dark Backdrop
            Color.black.opacity(0.35)
                .edgesIgnoringSafeArea(.all)

            // Floating Transfer Window Card
            VStack(alignment: .leading, spacing: 14) {
                // Header Bar with Icon, Title, and Percentage
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(progress.isCut ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: progress.isCut ? "arrow.right.doc.on.clipboard" : "doc.on.doc.fill")
                            .font(.system(size: 18))
                            .foregroundColor(progress.isCut ? .orange : .green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(progress.timeRemainingFormatted)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(progress.percentageString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(progress.isCut ? .orange : .green)
                }

                // Smooth Progress Bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .separatorColor))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: progress.isCut ? [Color.orange, Color.yellow] : [Color.green, Color.mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress.fractionCompleted))), height: 8)
                                .animation(.linear(duration: 0.2), value: progress.fractionCompleted)
                        }
                    }
                    .frame(height: 8)

                    // Sub-metrics under progress bar
                    HStack {
                        Text(progress.progressBytesFormatted)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(progress.speedFormatted)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Expandable Details (Windows 11 Explorer style)
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDetailsExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isDetailsExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(isDetailsExpanded ? "Fewer details" : "More details")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if isDetailsExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            if !progress.currentItemName.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("Name:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)

                                    Text(progress.currentItemName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            HStack(spacing: 8) {
                                Text("From:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)

                                Text(progress.sourceFolderName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                Text("To:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)

                                Text(progress.destinationFolderName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 8) {
                                Text("Items:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)

                                Text("\(progress.processedItems) of \(progress.totalItems) completed")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Footer Buttons (Cancel)
                HStack {
                    Spacer()

                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

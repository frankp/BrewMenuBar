import AppKit

/// Menu item view shown while upgrading: a title, a determinate progress bar and the current brew step.
final class UpgradeProgressView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Updating…")
    private let progressBar = NSProgressIndicator()
    private let stepLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 62))

        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.lineBreakMode = .byTruncatingTail

        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.controlSize = .small

        stepLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        stepLabel.textColor = .secondaryLabelColor
        stepLabel.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [titleLabel, progressBar, stepLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            titleLabel.widthAnchor.constraint(equalTo: progressBar.widthAnchor),
            stepLabel.widthAnchor.constraint(equalTo: progressBar.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, step: String, fraction: Double) {
        titleLabel.stringValue = title
        stepLabel.stringValue = step
        // Never move backwards within a run - brew's steps can arrive slightly out of order.
        progressBar.doubleValue = max(progressBar.doubleValue, min(fraction, 1))
    }
}

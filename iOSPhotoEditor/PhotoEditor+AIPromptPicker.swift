//
//  PhotoEditor+AIPromptPicker.swift
//  iOSPhotoEditor
//
//  Bottom-sheet UI for AI preset selection and multi-line custom prompt
//  entry. Replaces UIAlertController(.actionSheet) + (.alert) with a card
//  style that can show descriptions without truncation and lets users type
//  paragraph-length instructions.
//

import UIKit

// MARK: - Preset picker

final class AIPromptPickerViewController: UIViewController {

    struct Row {
        let id: String          // preset.id, or "_custom"
        let title: String
        let subtitle: String?
        let isCustom: Bool
    }

    private let rows: [Row]
    private let onPick: (String) -> Void
    private let onCancel: () -> Void
    private var didPick = false

    init(presets: [PhotoEditorAIPrompt],
         allowCustom: Bool,
         onPick: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        var rows = presets.map {
            Row(id: $0.id, title: $0.name, subtitle: $0.description, isCustom: false)
        }
        if allowCustom {
            rows.append(Row(id: "_custom", title: "Custom…",
                            subtitle: "Type your own instructions", isCustom: true))
        }
        self.rows = rows
        self.onPick = onPick
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)

        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 18
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let header = UILabel()
        header.text = "AI Annotations"
        header.font = .preferredFont(forTextStyle: .headline)
        header.textAlignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (i, row) in rows.enumerated() {
            stack.addArrangedSubview(makeRowButton(row))
            if i < rows.count - 1 {
                let sep = UIView()
                sep.backgroundColor = .separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(sep)
            }
        }

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !didPick { onCancel() }
    }

    private func makeRowButton(_ row: Row) -> UIView {
        let container = UIControl()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.accessibilityIdentifier = row.id
        container.addTarget(self, action: #selector(rowTouchDown(_:)), for: .touchDown)
        container.addTarget(self, action: #selector(rowTouchCancel(_:)),
                            for: [.touchUpOutside, .touchCancel, .touchDragExit])
        container.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)

        let icon = UIImageView(
            image: UIImage(systemName: row.isCustom ? "pencil.and.scribble" : "sparkles"))
        icon.tintColor = .tintColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = row.title
        title.font = .preferredFont(forTextStyle: .body).bold()
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = row.subtitle
        subtitle.font = .preferredFont(forTextStyle: .footnote)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.isHidden = (row.subtitle ?? "").isEmpty

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(textStack)
        container.addSubview(chevron)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),

            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),
        ])
        return container
    }

    @objc private func rowTouchDown(_ sender: UIControl) { sender.backgroundColor = .secondarySystemFill }
    @objc private func rowTouchCancel(_ sender: UIControl) { sender.backgroundColor = .clear }
    @objc private func rowTapped(_ sender: UIControl) {
        sender.backgroundColor = .clear
        guard let id = sender.accessibilityIdentifier else { return }
        didPick = true
        dismiss(animated: true) { [onPick] in onPick(id) }
    }
}

// MARK: - Multi-line prompt editor (custom + revise)

final class AIPromptEditorViewController: UIViewController, UITextViewDelegate {

    private let titleText: String
    private let subtitleText: String?
    private let initialText: String
    private let submitLabel: String
    private let placeholder: String
    private let onSubmit: (String) -> Void
    private let onCancel: () -> Void
    private var didSubmit = false

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private var submitButton: UIButton!

    init(title: String,
         subtitle: String? = nil,
         initialText: String = "",
         submitLabel: String = "Generate",
         placeholder: String = "",
         onSubmit: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        self.titleText = title
        self.subtitleText = subtitle
        self.initialText = initialText
        self.submitLabel = submitLabel
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)

        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 18
            sheet.selectedDetentIdentifier = .medium
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitleText
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = (subtitleText ?? "").isEmpty
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.widthTracksTextView = true
        textView.text = initialText
        textView.delegate = self
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .default
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text = placeholder
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.numberOfLines = 0
        placeholderLabel.lineBreakMode = .byWordWrapping
        placeholderLabel.isHidden = !initialText.isEmpty
        placeholderLabel.isUserInteractionEnabled = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        submitButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = submitLabel
        config.buttonSize = .medium
        config.cornerStyle = .large
        submitButton.configuration = config
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        updateSubmitEnabled()

        let buttons = UIStackView(arrangedSubviews: [cancelButton, UIView(), submitButton])
        buttons.axis = .horizontal
        buttons.alignment = .center
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(textView)
        view.addSubview(placeholderLabel)   // sibling (overlay) so constraints use the parent view's layout
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            textView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 18),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 18),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -18),

            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !didSubmit { onCancel() }
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSubmitEnabled()
    }

    private func updateSubmitEnabled() {
        submitButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func submitTapped() {
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        didSubmit = true
        textView.resignFirstResponder()
        dismiss(animated: true) { [onSubmit] in onSubmit(trimmed) }
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let d = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: d, size: 0)
    }
}

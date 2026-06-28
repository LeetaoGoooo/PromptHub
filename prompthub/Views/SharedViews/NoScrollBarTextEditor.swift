//
//  NoScrollBarTextEditor.swift
//  prompthub
//
//  Created by leetao on 2025/3/14.
//

import AppKit
import SwiftUI

struct NoScrollBarTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont? = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    var isEditable: Bool = true
    var becomeFirstResponder: Bool = false
    var autoScroll: Bool = true

    final class IntrinsicFreeScrollView: NSScrollView {
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        override var fittingSize: NSSize {
            .zero
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.font = font
        textView.isEditable = isEditable
        textView.string = text
        textView.delegate = context.coordinator
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = IntrinsicFreeScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true // Enable vertical scroller for better UX
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        if textView.string != text {
            // Save current selection
            let selectedRange = textView.selectedRange()

            // Update text
            textView.string = text

            // Restore selection if it was valid
            if selectedRange.location != NSNotFound && selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }

            // Auto-scroll to the bottom if enabled
            if autoScroll {
                DispatchQueue.main.async {
                    let range = NSRange(location: text.count, length: 0)
                    textView.scrollRangeToVisible(range)
                }
            }
        }
        textView.font = font
        textView.isEditable = isEditable
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor

        if becomeFirstResponder, context.coordinator.didRequestFirstResponder == false {
            context.coordinator.didRequestFirstResponder = true
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        } else if becomeFirstResponder == false {
            context.coordinator.didRequestFirstResponder = false
        }

        // Adjust text container to match scroll view width
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoScrollBarTextEditor
        var didRequestFirstResponder = false

        init(_ parent: NoScrollBarTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string

            if parent.autoScroll {
                let range = NSRange(location: textView.string.count, length: 0)
                textView.scrollRangeToVisible(range)
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            return parent.isEditable
        }
    }
}

#Preview {
    @Previewable @State var sampleText = "Sample text for NoScrollBarTextEditor\nThis is a multi-line text\nWith some content to demonstrate\nthe text editor functionality."
    
    VStack {
        Text("NoScrollBarTextEditor Preview")
            .font(.headline)
        
        NoScrollBarTextEditor(text: $sampleText)
            .frame(height: 200)
            .border(Color.gray, width: 1)
    }
    .padding()
}

import AppKit
import OSLog
import SwiftUI

@available(macOS 13.0, *)
private protocol HostingSizingConfigurable: AnyObject {
    var sizingOptions: NSHostingSizingOptions { get set }
}

@available(macOS 13.0, *)
extension NSHostingController: HostingSizingConfigurable {}

@available(macOS 13.0, *)
extension NSHostingView: HostingSizingConfigurable {}

private struct WindowMinimumContentSize: NSViewRepresentable {
    let minimumContentSize: CGSize
    let debugName: String

    func makeCoordinator() -> Coordinator {
        Coordinator(debugName: debugName)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        context.coordinator.minimumContentSize = minimumContentSize
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        context.coordinator.debugName = debugName
        context.coordinator.minimumContentSize = minimumContentSize
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView.window)
        context.coordinator.reconcileWindowConstraintsIfNeeded(reason: "updateNSView")

        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
            context.coordinator.reconcileWindowConstraintsIfNeeded(reason: "async-updateNSView")
        }
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
            coordinator?.scheduleWindowConstraintReconcile(reason: "viewDidMoveToWindow")
        }

        override func layout() {
            super.layout()
            coordinator?.scheduleWindowConstraintReconcile(reason: "trackingView.layout")
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PromptHub", category: "WindowSizing")

        weak var window: NSWindow?
        var minimumContentSize: CGSize = .zero
        var debugName: String
        private var pendingReconcileReasons: [String] = []
        private var isReconcileScheduled = false
        private var configuredHostingObjectIDs: Set<ObjectIdentifier> = []

        init(debugName: String) {
            self.debugName = debugName
        }

        func attach(to window: NSWindow?) {
            guard let window else { return }

            if self.window !== window {
                self.window = window
                logger.debug("attach windowSizing name=\(self.debugName, privacy: .public)")
            }

            configureHostingSizingIfNeeded(for: window)

            if window.delegate !== self {
                window.delegate = self
                logger.debug("assign delegate name=\(self.debugName, privacy: .public)")
            }
        }

        func windowWillStartLiveResize(_ notification: Notification) {
            reconcileWindowConstraintsIfNeeded(reason: "willStartLiveResize-preflight")
            logWindowState(reason: "willStartLiveResize")
        }

        func windowDidEndLiveResize(_ notification: Notification) {
            applyWindowConstraints(reason: "didEndLiveResize")
            logWindowState(reason: "didEndLiveResize")
        }

        func windowDidResize(_ notification: Notification) {
            reconcileWindowConstraintsIfNeeded(reason: "didResize")
            logWindowState(reason: "didResize")
        }

        func windowDidBecomeKey(_ notification: Notification) {
            reconcileWindowConstraintsIfNeeded(reason: "didBecomeKey")
        }

        func windowDidBecomeMain(_ notification: Notification) {
            reconcileWindowConstraintsIfNeeded(reason: "didBecomeMain")
        }

        func windowDidUpdate(_ notification: Notification) {
            reconcileWindowConstraintsIfNeeded(reason: "didUpdate")
        }

        func scheduleWindowConstraintReconcile(reason: String) {
            pendingReconcileReasons.append(reason)

            guard !isReconcileScheduled else { return }
            isReconcileScheduled = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isReconcileScheduled = false
                let combinedReason = self.pendingReconcileReasons.joined(separator: ",")
                self.pendingReconcileReasons.removeAll(keepingCapacity: true)
                self.reconcileWindowConstraintsIfNeeded(reason: combinedReason)
            }
        }

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let minimumFrameSize = minimumFrameSize(for: sender)
            let clampedSize = NSSize(
                width: max(frameSize.width, minimumFrameSize.width),
                height: max(frameSize.height, minimumFrameSize.height)
            )

            logger.debug(
                "willResize name=\(self.debugName, privacy: .public) requested=\(Self.sizeDescription(frameSize), privacy: .public) minFrame=\(Self.sizeDescription(minimumFrameSize), privacy: .public) clamped=\(Self.sizeDescription(clampedSize), privacy: .public)"
            )

            return clampedSize
        }

        func applyWindowConstraints(reason: String) {
            guard let window else { return }

            attach(to: window)

            let contentSize = normalizedContentSize
            let minimumFrameSize = minimumFrameSize(for: window)

            if window.contentMinSize != contentSize {
                window.contentMinSize = contentSize
            }

            if window.minSize != minimumFrameSize {
                window.minSize = minimumFrameSize
            }

            let clampedFrameSize = NSSize(
                width: max(window.frame.size.width, minimumFrameSize.width),
                height: max(window.frame.size.height, minimumFrameSize.height)
            )

            if clampedFrameSize != window.frame.size {
                var frame = window.frame
                frame.size = clampedFrameSize
                window.setFrame(frame, display: true, animate: false)

                logger.debug(
                    "clampFrame name=\(self.debugName, privacy: .public) reason=\(reason, privacy: .public) frame=\(Self.sizeDescription(clampedFrameSize), privacy: .public) minFrame=\(Self.sizeDescription(minimumFrameSize), privacy: .public)"
                )
            }
        }

        func reconcileWindowConstraintsIfNeeded(reason: String) {
            guard let window else { return }

            let expectedContentSize = normalizedContentSize
            let expectedFrameSize = minimumFrameSize(for: window)
            let contentViewFittingSize = window.contentView?.fittingSize ?? .zero
            let hasContentDrift = window.contentMinSize != expectedContentSize
            let hasFrameDrift = window.minSize != expectedFrameSize

            guard hasContentDrift || hasFrameDrift else { return }

            logger.debug(
                "constraintDrift name=\(self.debugName, privacy: .public) reason=\(reason, privacy: .public) expectedContent=\(Self.sizeDescription(expectedContentSize), privacy: .public) actualContent=\(Self.sizeDescription(window.contentMinSize), privacy: .public) expectedFrame=\(Self.sizeDescription(expectedFrameSize), privacy: .public) actualFrame=\(Self.sizeDescription(window.minSize), privacy: .public) fitting=\(Self.sizeDescription(contentViewFittingSize), privacy: .public)"
            )

            applyWindowConstraints(reason: "reconcile-\(reason)")
        }

        private var normalizedContentSize: NSSize {
            NSSize(
                width: max(0, minimumContentSize.width),
                height: max(0, minimumContentSize.height)
            )
        }

        private func minimumFrameSize(for window: NSWindow) -> NSSize {
            window.frameRect(forContentRect: NSRect(origin: .zero, size: normalizedContentSize)).size
        }

        private func configureHostingSizingIfNeeded(for window: NSWindow) {
            guard #available(macOS 13.0, *) else { return }

            if let controller = window.contentViewController as? any HostingSizingConfigurable {
                configureHostingSizingIfNeeded(for: controller, label: String(describing: type(of: controller)))
            }

            if let contentView = window.contentView {
                configureHostingSizingRecursively(in: contentView)
            }
        }

        @available(macOS 13.0, *)
        private func configureHostingSizingRecursively(in view: NSView) {
            if let hostingView = view as? any HostingSizingConfigurable {
                configureHostingSizingIfNeeded(for: hostingView, label: String(describing: type(of: view)))
            }

            for subview in view.subviews {
                configureHostingSizingRecursively(in: subview)
            }
        }

        @available(macOS 13.0, *)
        private func configureHostingSizingIfNeeded(for hostingObject: any HostingSizingConfigurable, label: String) {
            let objectID = ObjectIdentifier(hostingObject)
            guard !configuredHostingObjectIDs.contains(objectID) else { return }

            let previousOptions = hostingObject.sizingOptions
            let newOptions = previousOptions.subtracting([.minSize, .intrinsicContentSize])
            hostingObject.sizingOptions = newOptions
            configuredHostingObjectIDs.insert(objectID)

            logger.debug(
                "hostingSizing name=\(self.debugName, privacy: .public) target=\(label, privacy: .public) previous=\(Self.sizingOptionsDescription(previousOptions), privacy: .public) new=\(Self.sizingOptionsDescription(newOptions), privacy: .public)"
            )
        }

        private func logWindowState(reason: String) {
            guard let window else { return }

            logger.debug(
                "windowState name=\(self.debugName, privacy: .public) reason=\(reason, privacy: .public) frame=\(Self.sizeDescription(window.frame.size), privacy: .public) minFrame=\(Self.sizeDescription(window.minSize), privacy: .public) minContent=\(Self.sizeDescription(window.contentMinSize), privacy: .public)"
            )
        }

        private static func sizeDescription(_ size: NSSize) -> String {
            "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        }

        @available(macOS 13.0, *)
        private static func sizingOptionsDescription(_ options: NSHostingSizingOptions) -> String {
            var labels: [String] = []

            if options.contains(.minSize) {
                labels.append("minSize")
            }
            if options.contains(.intrinsicContentSize) {
                labels.append("intrinsic")
            }
            if options.contains(.maxSize) {
                labels.append("maxSize")
            }
            if options.contains(.preferredContentSize) {
                labels.append("preferred")
            }
            if options.contains(.standardBounds) {
                labels.append("standardBounds")
            }

            return labels.isEmpty ? "[]" : labels.joined(separator: ",")
        }
    }
}

extension View {
    func enforceWindowMinimumContentSize(_ minimumContentSize: CGSize, debugName: String) -> some View {
        background(WindowMinimumContentSize(minimumContentSize: minimumContentSize, debugName: debugName))
    }
}
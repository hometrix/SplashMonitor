import SwiftUI
import AppKit

/// Un NSTextView enriquecido para macOS que envía con Enter directo y crea nueva línea con Shift+Enter.
public struct MacChatInputField: NSViewRepresentable {
    @Binding public var text: String
    public var onCommit: () -> Void
    public var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    
    public init(
        text: Binding<String>,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        onCommit: @escaping () -> Void
    ) {
        self._text = text
        self.font = font
        self.onCommit = onCommit
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = font
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        textView.onCommit = onCommit
        
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? CustomTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
        textView.onCommit = onCommit
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacChatInputField
        weak var textView: CustomTextView?
        
        init(_ parent: MacChatInputField) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
    
    public class CustomTextView: NSTextView {
        var onCommit: (() -> Void)?
        
        public override func keyDown(with event: NSEvent) {
            // Enter sin Shift = Enviar mensaje
            if event.keyCode == 36 { // Return key
                if event.modifierFlags.contains(.shift) {
                    // Shift + Enter: insertar salto de línea
                    super.insertNewline(nil)
                } else if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) {
                    onCommit?()
                    return
                } else {
                    super.keyDown(with: event)
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }
}


import SwiftUI
import AppKit

// MARK: - Message Bubble View

public struct MessageBubbleView: View {
    public let message: ChatMessage
    @ObservedObject private var zoomManager = TextZoomManager.shared
    @State private var isThinkingExpanded: Bool = false
    @State private var copied: Bool = false
    
    public init(message: ChatMessage) {
        self.message = message
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                avatarView
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Adjuntos (si existen)
                if !message.attachments.isEmpty {
                    attachmentsPreview
                }
                
                // Bloque de pensamiento colapsable (si existe)
                if let thinking = message.thinkingContent, !thinking.isEmpty {
                    thinkingBlock(thinking)
                }
                
                // Contenido principal del mensaje
                contentBlock
                
                // Barra de telemetría y acciones para el asistente
                if message.role == .assistant {
                    telemetryAndActionsBar
                }
            }
            
            if message.role == .user {
                avatarView
            } else {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - Avatar
    
    private var attachmentsPreview: some View {
        HStack(spacing: 6) {
            ForEach(message.attachments) { att in
                HStack(spacing: 4) {
                    Image(systemName: att.isImage ? "photo.fill" : "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(att.name)
                        .font(.caption)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
        }
    }
    
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    message.role == .user
                    ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.cyan.opacity(0.8), Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 28, height: 28)
            
            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                AppIconView(size: 20)
            }
        }
    }
    
    // MARK: - Thinking Block
    
    private func thinkingBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isThinkingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(Localization.shared.isSpanish ? "Proceso de Razonamiento (Thinking)" : "Reasoning Process (Thinking)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isThinkingExpanded {
                ScrollView {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 140)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Content Block
    
    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.content.isEmpty && !message.isComplete {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(Localization.shared.isSpanish ? "Generando respuesta..." : "Generating response...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            } else {
                renderMarkdown(message.content)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            message.role == .user
            ? Color.accentColor.opacity(0.2)
            : Color(nsColor: .controlBackgroundColor).opacity(0.85)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(message.role == .user ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Markdown / Code Rendering
    
    @ViewBuilder
    private func renderMarkdown(_ content: String) -> some View {
        let components = parseMarkdownComponents(content)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(components.indices, id: \.self) { idx in
                let comp = components[idx]
                if comp.isCodeBlock {
                    codeBlockView(code: comp.text, language: comp.language)
                } else {
                    formattedTextView(comp.text)
                }
            }
        }
    }
    
    @ViewBuilder
    private func formattedTextView(_ rawText: String) -> some View {
        let baseSize = NSFont.preferredFont(forTextStyle: .body).pointSize * zoomManager.zoomScale
        if let attributed = try? AttributedString(markdown: rawText, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(size: baseSize))
                .lineSpacing(4 * zoomManager.zoomScale)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        } else {
            Text(rawText)
                .font(.system(size: baseSize))
                .lineSpacing(4 * zoomManager.zoomScale)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
    
    private func codeBlockView(code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? (Localization.shared.isSpanish ? "Copiado" : "Copied") : (Localization.shared.isSpanish ? "Copiar" : "Copy"))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.4))
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.85, green: 0.95, blue: 0.9))
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color.black.opacity(0.85))
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Telemetry & Actions Bar
    
    private var telemetryAndActionsBar: some View {
        HStack(spacing: 8) {
            if let tps = message.tokensPerSecond, tps > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                    Text("\(String(format: "%.1f", tps)) tok/s")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
            }
            
            if let tokens = message.tokensGenerated, tokens > 0 {
                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))
                Text("\(tokens) tokens")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            if let ttft = message.ttftMs, ttft > 0 {
                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))
                Text("TTFT: \(String(format: "%.0f", ttft)) ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Botón rápido de copiado de toda la respuesta
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Localization.shared.isSpanish ? "Copiar respuesta completa" : "Copy full response")
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Markdown Parsing Helper
    
    private struct MarkdownChunk {
        let text: String
        let isCodeBlock: Bool
        let language: String
    }
    
    private func parseMarkdownComponents(_ raw: String) -> [MarkdownChunk] {
        var chunks: [MarkdownChunk] = []
        let parts = raw.components(separatedBy: "```")
        
        for i in 0..<parts.count {
            let chunk = parts[i]
            if i % 2 == 1 {
                // Es un bloque de código
                var lines = chunk.components(separatedBy: "\n")
                let lang = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !lines.isEmpty {
                    lines.removeFirst()
                }
                let codeContent = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                chunks.append(MarkdownChunk(text: codeContent, isCodeBlock: true, language: lang))
            } else {
                // Es texto normal
                let textContent = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !textContent.isEmpty {
                    chunks.append(MarkdownChunk(text: textContent, isCodeBlock: false, language: ""))
                }
            }
        }
        
        return chunks.isEmpty ? [MarkdownChunk(text: raw, isCodeBlock: false, language: "")] : chunks
    }
}


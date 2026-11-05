import SwiftUI
import AppKit

public struct ModelManagerView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @State private var selectedTab: Int = 0 // 0: Instalados, 1: Explorar HF, 2: Personalizado
    @State private var customRepoId: String = ""
    @State private var customModelLanguageOnly: Bool = false
    @State private var searchText: String = ""
    
    // Model deletion alert state
    @State private var showingDeleteAlert: Bool = false
    @State private var modelToDelete: InstalledSplashModel? = nil
    @State private var copiedLogs: Bool = false
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Segmented Picker
            Picker("", selection: $selectedTab) {
                Text("\(tr(es: "Instalados", en: "Installed")) (\(service.installedModels.count))").tag(0)
                Text("Hugging Face").tag(1)
                Text(tr(es: "Instalar", en: "Install")).tag(2)
            }
            .pickerStyle(.segmented)
            
            // Tab Content
            switch selectedTab {
            case 0:
                installedModelsList
            case 1:
                onlineModelsList
            case 2:
                customInstallView
            default:
                EmptyView()
            }
            
            // Installation Console (visible if installing or recently installed)
            if service.isInstalling || !service.installLogs.isEmpty {
                installationConsoleView
            }
        }
        .alert(
            tr(es: "¿Eliminar Modelo?", en: "Delete Model?"),
            isPresented: $showingDeleteAlert,
            presenting: modelToDelete
        ) { model in
            Button(tr(es: "Eliminar de Splash", en: "Delete from Splash"), role: .destructive) {
                service.deleteModel(repoId: model.repoId)
            }
            Button(tr(es: "Cancelar", en: "Cancel"), role: .cancel) {}
        } message: { model in
            Text(tr(
                es: "¿Estás seguro de que deseas eliminar '\(model.shortName)'? Se desvinculará del motor Splash y liberará espacio en disco (\(model.formattedSize)).",
                en: "Are you sure you want to delete '\(model.shortName)'? It will be unlinked from the Splash engine to free up disk space (\(model.formattedSize))."
            ))
        }
        .alert(
            item: $service.portConflict
        ) { conflict in
            Alert(
                title: Text(tr(es: "⚠️ Puerto \(conflict.port) en Uso", en: "⚠️ Port \(conflict.port) In Use")),
                message: Text(tr(
                    es: "El proceso '\(conflict.processName)' (PID \(conflict.pid)) está utilizando el puerto \(conflict.port).\n\n¿Deseas cambiar al puerto libre sugerido \(conflict.suggestedPort) o liberar el puerto \(conflict.port)?",
                    en: "Process '\(conflict.processName)' (PID \(conflict.pid)) is currently using port \(conflict.port).\n\nWould you like to switch to suggested free port \(conflict.suggestedPort) or free port \(conflict.port)?"
                )),
                primaryButton: .default(Text(tr(es: "Usar puerto \(conflict.suggestedPort)", en: "Use port \(conflict.suggestedPort)"))) {
                    service.useSuggestedPort(conflict.suggestedPort)
                },
                secondaryButton: .destructive(Text(tr(es: "Liberar puerto \(conflict.port)", en: "Free port \(conflict.port)"))) {
                    service.resolvePortConflict(killProcess: true)
                }
            )
        }
    }
    
    // MARK: - Installed Models Tab
    private var installedModelsList: some View {
        VStack(spacing: 8) {
            if service.installedModels.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(tr(es: "No hay modelos instalados en Splash aún.", en: "No models installed in Splash yet."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(tr(es: "Explora el catálogo de Hugging Face para descargar el primer modelo.", en: "Browse the Hugging Face catalog to download your first model."))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(service.installedModels) { model in
                            HStack(spacing: 10) {
                                Image(systemName: model.isCurrentlyActive ? "checkmark.circle.fill" : "cube.box")
                                    .font(.system(size: 15))
                                    .foregroundColor(model.isCurrentlyActive ? .green : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(model.shortName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                        if model.isCurrentlyActive {
                                            Text(tr(es: "ACTIVO", en: "ACTIVE"))
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.green.opacity(0.2))
                                                .foregroundColor(.green)
                                                .cornerRadius(4)
                                        }
                                        if let variant = model.variant {
                                            Text(variant)
                                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                        if model.isCoderFineTune {
                                            Text(tr(es: "CODER", en: "CODER"))
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.15))
                                                .foregroundColor(.orange)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(model.repoId)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text("·")
                                            .foregroundColor(.secondary)
                                        Text(model.formattedSize)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.primary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Reveal in Finder button
                                Button {
                                    service.openModelInFinder(repoId: model.repoId)
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help(tr(es: "Mostrar carpeta en el Finder", en: "Reveal folder in Finder"))
                                
                                // Delete Model button
                                Button {
                                    modelToDelete = model
                                    showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                                .help(tr(es: "Eliminar modelo para liberar espacio", en: "Delete model to free up space"))
                                
                                if !model.isCurrentlyActive {
                                    Button {
                                        service.switchModel(to: model.repoId)
                                    } label: {
                                        if service.isStartingServer && service.startingModelId == model.repoId {
                                            HStack(spacing: 5) {
                                                ProgressView()
                                                    .controlSize(.mini)
                                                Text(service.isRunning ? tr(es: "Cambiando...", en: "Switching...") : tr(es: "Iniciando...", en: "Starting..."))
                                                    .font(.system(size: 10, weight: .semibold))
                                            }
                                        } else {
                                            Label(
                                                service.isRunning ? tr(es: "Cambiar", en: "Switch") : tr(es: "Arrancar", en: "Start"),
                                                systemImage: service.isRunning ? "arrow.triangle.2.circlepath" : "play.fill"
                                            )
                                            .font(.system(size: 10, weight: .semibold))
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(service.isRunning ? .purple : .green)
                                    .controlSize(.small)
                                    .disabled(service.isStartingServer)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 380)
            }
        }
    }
    
    // MARK: - Online Models Tab
    private var onlineModelsList: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField(tr(es: "Buscar modelos...", en: "Search models..."), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                }
                .padding(5)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .cornerRadius(6)
                
                Button {
                    Task {
                        await service.fetchOnlineModels()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(service.isLoadingOnlineModels)
            }
            
            if service.isLoadingOnlineModels {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(tr(es: "Cargando catálogo de Hugging Face...", en: "Loading Hugging Face catalog..."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                let filtered = service.availableOnlineModels.filter {
                    searchText.isEmpty || $0.id.localizedCaseInsensitiveContains(searchText)
                }
                
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(filtered) { item in
                            let isInstalled = service.installedModels.contains { $0.repoId == item.id }
                            
                            HStack(spacing: 10) {
                                Image(systemName: item.isOfficial ? "sparkles" : "cube")
                                    .font(.system(size: 14))
                                    .foregroundColor(item.isOfficial ? .blue : .purple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.displayName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                        if item.isOfficial {
                                            Text(tr(es: "OFICIAL", en: "OFFICIAL"))
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(3)
                                        } else if item.id.hasSuffix("-Splash") {
                                            Text(tr(es: "DESCONTINUADO", en: "DEPRECATED"))
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.red.opacity(0.2))
                                                .foregroundColor(.red)
                                                .cornerRadius(3)
                                        }
                                    }
                                    
                                    Text(item.id)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isInstalled {
                                    Text(tr(es: "Instalado", en: "Installed"))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15))
                                        .cornerRadius(4)
                                } else {
                                    Button {
                                        service.installModel(repoId: item.id)
                                    } label: {
                                        Label(tr(es: "Instalar", en: "Install"), systemImage: "arrow.down.circle")
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(service.isInstalling)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 380)
            }
        }
    }
    
    // MARK: - Custom Install Tab
    private var customInstallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr(es: "Instalar modelo desde Hugging Face", en: "Install model from Hugging Face"))
                .font(.system(size: 12, weight: .semibold))
            
            Text(tr(
                es: "Introduce el identificador de repositorio en Hugging Face (ej. mlx-community/Qwen3.8-27B-4bit) o fine-tune GGUF con variante (ej. peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL).",
                en: "Enter the Hugging Face repository (e.g. mlx-community/Qwen3.8-27B-4bit) or GGUF fine-tune with variant (e.g. peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL)."
            ))
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            
            HStack {
                TextField(tr(es: "propietario/modelo[:variante] (ej. mlx-community/Qwen3.8-27B-4bit)", en: "owner/repo[:variant] (e.g. mlx-community/Qwen3.8-27B-4bit)"), text: $customRepoId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: customRepoId) { newVal in
                        let lower = newVal.lowercased()
                        if lower.contains("coder") || lower.contains("code") {
                            customModelLanguageOnly = true
                        }
                    }
                
                Button {
                    let trimmed = customRepoId.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    service.installModel(repoId: trimmed, languageOnly: customModelLanguageOnly)
                } label: {
                    Text(tr(es: "Descargar", en: "Download"))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(service.isInstalling || customRepoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Toggle(isOn: $customModelLanguageOnly) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(tr(
                        es: "Modo solo texto / código (--language-only, requerido para modelos Coder sin mmproj)",
                        en: "Text/code-only mode (--language-only, required for Coder models without mmproj)"
                    ))
                    .font(.system(size: 10))
                }
            }
            .toggleStyle(.checkbox)
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                Text(tr(
                    es: "Los pesos se descargan en el caché de Hugging Face y se optimizan con kernels Metal precompilados.",
                    en: "Weights download directly to the Hugging Face cache and configure with precompiled Metal kernels."
                ))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Installation Console View
    private var installationConsoleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if service.isInstalling {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("\(tr(es: "Instalando", en: "Installing")): \(service.installingModelId ?? "")...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                } else if service.installSuccess == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(tr(es: "Instalación completada", en: "Installation completed"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                } else if service.installSuccess == false {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(tr(es: "Fallo en la instalación", en: "Installation failed"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if !service.installLogs.isEmpty {
                    Button {
                        let text = service.installLogs.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        copiedLogs = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedLogs = false
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copiedLogs ? "checkmark" : "doc.on.doc")
                            Text(copiedLogs ? tr(es: "¡Copiado!", en: "Copied!") : tr(es: "Copiar Logs", en: "Copy Logs"))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(copiedLogs ? .green : .cyan)
                    }
                    .buttonStyle(.borderless)
                }
                
                if service.isInstalling {
                    Button(role: .destructive) {
                        service.cancelModelInstall()
                    } label: {
                        Text(tr(es: "Cancelar Descarga", en: "Cancel Download"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button(tr(es: "Cerrar", en: "Close")) {
                        service.installLogs.removeAll()
                        service.installSuccess = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                }
            }
            
            // Gated Repository Help Banner
            if isGatedError {
                gatedModelHelpBanner
            }
            
            // Live Download Telemetry Banner
            if service.isInstalling {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        // Fase actual del proceso
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text(service.downloadPhase.isEmpty ? tr(es: "Descargando componentes...", en: "Downloading components...") : service.downloadPhase)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Velocidad en tiempo real (MB/s)
                        if service.downloadSpeedMBs > 0.05 {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 9))
                                Text(String(format: "%.1f MB/s", service.downloadSpeedMBs))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.18))
                            .cornerRadius(4)
                        }
                        
                        // Bytes transferidos / Total esperado
                        if service.downloadedBytes > 0 {
                            Text(formatDownloadProgress(downloaded: service.downloadedBytes, total: service.totalExpectedBytes))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.9))
                        }
                    }
                    
                    // Barra de progreso elegante
                    if let fraction = service.downloadProgressFraction {
                        ProgressView(value: fraction, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.cyan)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(.cyan)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.45))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                )
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(service.installLogs.enumerated()), id: \.offset) { idx, log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.92))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(8)
                    .textSelection(.enabled)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                .onChange(of: service.installLogs.count) { _ in
                    if let last = service.installLogs.indices.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formatDownloadProgress(downloaded: Int64, total: Int64) -> String {
        let dlGB = Double(downloaded) / 1_073_741_824.0
        let dlMB = Double(downloaded) / 1_048_576.0
        let dlStr = dlGB >= 1.0 ? String(format: "%.2f GB", dlGB) : String(format: "%.0f MB", dlMB)
        if total > 0 {
            let totGB = Double(total) / 1_073_741_824.0
            let pct = min(100, Int((Double(downloaded) / Double(total)) * 100))
            return "\(dlStr) / \(String(format: "%.2f GB", totGB)) (\(pct)%)"
        } else {
            return "\(dlStr) recibidos"
        }
    }
    
    // MARK: - Gated Model Guidance
    private var isGatedError: Bool {
        service.installSuccess == false &&
        service.installLogs.contains { line in
            line.contains("gated repo") || line.contains("Access to model") || line.contains("403") || line.contains("Gated")
        }
    }
    
    private var targetGatedModelId: String? {
        if let current = service.installingModelId, !current.isEmpty {
            return current
        }
        let custom = customRepoId.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? nil : custom
    }
    
    private var gatedModelHelpBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr(
                        es: "Modelo con acceso restringido ('Gated')",
                        en: "Restricted Access Model ('Gated')"
                    ))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    
                    Text(tr(
                        es: "Hugging Face requiere que autorices el acceso con tu cuenta antes de descargar.",
                        en: "Hugging Face requires you to authorize access with your account before downloading."
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                if let modelId = targetGatedModelId,
                   let url = URL(string: "https://huggingface.co/\(modelId)") {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                            Text(tr(es: "Solicitar Acceso en HF", en: "Request Access on HF"))
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
            
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                    .padding(.top, 1)
                
                Text(tr(
                    es: "La mayoría de estos modelos tienen aprobación instantánea ('auto'). Al pulsar 'Agree and access repository' en tu navegador, tu cuenta quedará habilitada y podrás volver a pulsar 'Descargar'.",
                    en: "Most of these models have instant approval ('auto'). Once you click 'Agree and access repository' in your browser, your account is enabled and you can click 'Download' again."
                ))
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.35))
            .cornerRadius(6)
        }
        .padding(10)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1)
        )
    }
}

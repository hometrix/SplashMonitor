import SwiftUI

public struct ModelManagerView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @State private var selectedTab: Int = 0 // 0: Instalados, 1: Explorar HF, 2: Personalizado
    @State private var customRepoId: String = ""
    @State private var searchText: String = ""
    
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
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(model.repoId)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text("·")
                                            .foregroundColor(.secondary)
                                        Text(model.formattedSize)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if !model.isCurrentlyActive {
                                    Button {
                                        service.switchModel(to: model.repoId)
                                    } label: {
                                        Label(
                                            service.isRunning ? tr(es: "Cambiar", en: "Switch") : tr(es: "Arrancar", en: "Start"),
                                            systemImage: service.isRunning ? "arrow.triangle.2.circlepath" : "play.fill"
                                        )
                                        .font(.system(size: 10, weight: .semibold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(service.isRunning ? .purple : .green)
                                    .controlSize(.small)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 200)
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
                .frame(maxHeight: 200)
            }
        }
    }
    
    // MARK: - Custom Install Tab
    private var customInstallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr(es: "Instalar modelo desde Hugging Face", en: "Install model from Hugging Face"))
                .font(.system(size: 12, weight: .semibold))
            
            Text(tr(
                es: "Introduce el identificador de repositorio que contiene un paquete Splash (ej. incoai/Qwen3.8-27B-Splash).",
                en: "Enter the repository identifier containing a Splash package (e.g. incoai/Qwen3.8-27B-Splash)."
            ))
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            
            HStack {
                TextField(tr(es: "propietario/modelo (ej. incoai/Qwen3.8-27B-Splash)", en: "owner/repo (e.g. incoai/Qwen3.8-27B-Splash)"), text: $customRepoId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                
                Button {
                    let trimmed = customRepoId.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    service.installModel(repoId: trimmed)
                } label: {
                    Text(tr(es: "Descargar", en: "Download"))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(service.isInstalling || customRepoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
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
                
                if !service.isInstalling {
                    Button(tr(es: "Cerrar", en: "Close")) {
                        service.installLogs.removeAll()
                        service.installSuccess = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(service.installLogs.enumerated()), id: \.offset) { idx, log in
                            Text(log)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.primary.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(6)
                }
                .frame(height: 70)
                .background(Color.black.opacity(0.75))
                .cornerRadius(6)
                .onChange(of: service.installLogs.count) { _ in
                    if let last = service.installLogs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
        .cornerRadius(8)
    }
}

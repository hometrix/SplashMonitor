import SwiftUI

public struct TokenMetricsView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Speed Hero Cards
            HStack(spacing: 12) {
                MetricCard(
                    title: tr(es: "DECODE (Salida)", en: "DECODE (Output)"),
                    value: "\(service.formattedDecodeSpeed)",
                    unit: "tok/s",
                    subtitle: "\(service.formattedTokensDecode) \(tr(es: "tokens", en: "tokens"))",
                    icon: "bolt.fill",
                    tint: .green
                )
                
                MetricCard(
                    title: tr(es: "PREFILL (Entrada)", en: "PREFILL (Input)"),
                    value: "\(service.formattedPrefillSpeed)",
                    unit: "tok/s",
                    subtitle: "\(service.formattedTokensPrefill) \(tr(es: "tokens", en: "tokens"))",
                    icon: "arrow.down.forward.circle.fill",
                    tint: .blue
                )
            }
            
            // Sparkline / Mini Speed History
            if !service.speedHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tr(es: "Historial de Velocidad (Decode)", en: "Decode Speed History"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(service.formattedDecodeSpeed) tok/s \(tr(es: "actual", en: "current"))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    SpeedMiniChart(data: service.speedHistory)
                        .frame(height: 38)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        .cornerRadius(6)
                }
                .padding(8)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                .cornerRadius(8)
            }
            
            // Efficiency Metrics (Prefix Cache & DFlash Speculative Decoding)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    MiniStatRow(
                        title: tr(es: "Caché KV Reutilizado", en: "Reused KV Cache"),
                        value: service.formattedTokensReused,
                        detail: "\(service.formattedCacheHitRate) \(tr(es: "acierto", en: "hit rate"))",
                        icon: "arrow.triangle.2.circlepath",
                        tint: .cyan
                    )
                    
                    MiniStatRow(
                        title: tr(es: "Especulación DFlash 2", en: "DFlash 2 Speculation"),
                        value: service.formattedDraftAcceptanceRate,
                        detail: tr(es: "Aceptación draft", en: "Draft acceptance"),
                        icon: "sparkles",
                        tint: .orange
                    )
                }
                
                HStack(spacing: 12) {
                    MiniStatRow(
                        title: tr(es: "Latencia TTFT (p50)", en: "Latency TTFT (p50)"),
                        value: String(format: "%.0f ms", service.status?.metrics?.ttftMs?.p50 ?? 0.0),
                        detail: tr(es: "Primer token", en: "Time to first token"),
                        icon: "timer",
                        tint: .purple
                    )
                    
                    MiniStatRow(
                        title: tr(es: "Latencia ITL (p50)", en: "Latency ITL (p50)"),
                        value: String(format: "%.1f ms", service.status?.metrics?.itlMs?.p50 ?? 0.0),
                        detail: tr(es: "Entre tokens", en: "Inter-token latency"),
                        icon: "waveform.path.ecg",
                        tint: .indigo
                    )
                }
            }
            
            // Hardware & Metal Memory Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label {
                        Text(tr(es: "Memoria Unificada Metal", en: "Unified Metal Memory"))
                            .font(.system(size: 11, weight: .medium))
                    } icon: {
                        Image(systemName: "memorychip")
                            .foregroundColor(.pink)
                    }
                    
                    Spacer()
                    
                    Text("\(service.formattedMemoryUsed) / \(service.formattedMemoryLimit)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .separatorColor))
                            .frame(height: 7)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: service.memoryUsageRatio > 0.85 ? [.orange, .red] : [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(service.memoryUsageRatio)), height: 7)
                    }
                }
                .frame(height: 7)
                
                if let dev = service.status?.memoryPlan?.device {
                    HStack {
                        Text("\(dev.deviceName ?? "Apple Silicon") · \(dev.gpuCoreCount ?? 0) Cores GPU")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(tr(es: "Presión", en: "Pressure")): \(service.status?.memoryPressure?.capitalized ?? "Normal")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(service.status?.memoryPressure == "normal" ? .green : .orange)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .cornerRadius(8)
            
            // Requests Overview
            let reqs = service.status?.requests
            HStack(spacing: 14) {
                RequestPill(title: tr(es: "Completadas", en: "Completed"), count: reqs?.completed ?? 0, color: .green)
                RequestPill(title: tr(es: "En Cola", en: "Queued"), count: service.status?.scheduler?.queued ?? 0, color: .blue)
                RequestPill(title: tr(es: "Canceladas", en: "Cancelled"), count: reqs?.cancelled ?? 0, color: .gray)
                RequestPill(title: tr(es: "Fallos", en: "Failed"), count: reqs?.failed ?? 0, color: .red)
            }
            .font(.system(size: 10))
            
            // JMGREP Developers signature
            HStack(spacing: 5) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("JMGREP Developers")
                    .font(.system(size: 10, weight: .bold))
                Text("By Joan Gregorio Pérez - Ingeniero en software")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Subcomponents

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

struct MiniStatRow: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
    }
}

struct RequestPill: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title):")
                .foregroundColor(.secondary)
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct SpeedMiniChart: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geo in
            let maxVal = max(data.max() ?? 10.0, 10.0)
            Path { path in
                guard data.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(data.count - 1)
                for (index, val) in data.enumerated() {
                    let normY = 1.0 - CGFloat(val / maxVal)
                    let pt = CGPoint(x: CGFloat(index) * stepX, y: max(2, min(geo.size.height - 2, normY * geo.size.height)))
                    if index == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
            }
            .stroke(
                LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

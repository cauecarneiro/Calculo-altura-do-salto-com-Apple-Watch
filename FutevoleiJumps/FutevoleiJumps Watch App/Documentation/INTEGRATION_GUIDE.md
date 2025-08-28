# Guia de Integração - Jump Tracker

Este guia mostra como integrar o sistema Jump Tracker em outros projetos.

## 🚀 Setup Rápido

### 1. Copiar Arquivos Necessários

Copie os seguintes arquivos para seu projeto:

```
Core/
├── JumpDetector.swift              # ✅ Obrigatório
Models/
├── JumpData.swift                  # ✅ Obrigatório  
├── JumpConfiguration.swift         # ✅ Obrigatório
ViewModels/
└── JumpTrackerViewModel.swift      # 🔶 Opcional (se usar MVVM)
```

### 2. Configurar Permissões

Adicione ao `Info.plist`:

```xml
<key>NSMotionUsageDescription</key>
<string>Este app usa dados de movimento para detectar saltos</string>
```

### 3. Integração Básica

```swift
import SwiftUI

struct YourJumpView: View {
    @StateObject private var jumpDetector = JumpDetector()
    
    var body: some View {
        VStack {
            Text("Último: \(String(format: "%.0f cm", jumpDetector.lastJumpHeight * 100))")
            Text("Melhor: \(String(format: "%.0f cm", jumpDetector.bestJumpHeight * 100))")
        }
        .onAppear {
            jumpDetector.start()
        }
        .onDisappear {
            jumpDetector.stop()
        }
    }
}
```

## 🏗️ Integração Avançada (MVVM)

### 1. Usar o ViewModel

```swift
struct AdvancedJumpView: View {
    @StateObject private var viewModel = JumpTrackerViewModel()
    
    var body: some View {
        VStack {
            if viewModel.hasValidData {
                Text(viewModel.lastJumpFormatted)
                Text(viewModel.bestJumpFormatted)
            } else {
                Text("Faça um salto!")
            }
            
            if viewModel.isActive {
                Text("🟢 Ativo")
            } else {
                Text("🔴 Inativo")
            }
        }
        .onAppear {
            viewModel.startDetection()
        }
        .onDisappear {
            viewModel.stopDetection()
        }
        .alert("Erro", isPresented: $viewModel.hasError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

### 2. Observar Saltos Detectados

```swift
class MyJumpObserver: ObservableObject {
    @Published var jumpHistory: [JumpData] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: .jumpDetected)
            .sink { [weak self] _ in
                self?.handleNewJump()
            }
            .store(in: &cancellables)
    }
    
    private func handleNewJump() {
        // Adicionar lógica personalizada aqui
        print("🎉 Novo salto detectado!")
    }
}
```

## 🎛️ Configuração Personalizada

### 1. Configuração Customizada

```swift
struct MySportsConfiguration: JumpConfiguration {
    // Mais sensível para esportes específicos
    let freefallThreshold: Double = 0.30
    let groundThreshold: Double = 1.25
    let minJumpScore: Double = 6.0
    
    // Configuração específica para seu esporte
    let minFlightTime: Double = 0.08    // Permite saltos menores
    let maxFlightTime: Double = 2.0     // Permite saltos mais longos
}
```

### 2. Detector Customizado

```swift
class CustomJumpDetector: JumpDetector {
    private let customConfig = MySportsConfiguration()
    
    override func start() {
        // Aplicar configurações customizadas
        super.start()
        
        // Thresholds personalizados
        setCustomFreefallThreshold(customConfig.freefallThreshold)
        setCustomGroundThreshold(customConfig.groundThreshold)
    }
}
```

## 📊 Coleta de Dados Avançada

### 1. Histórico de Saltos

```swift
class JumpHistoryManager: ObservableObject {
    @Published var jumpHistory: [JumpRecord] = []
    
    struct JumpRecord {
        let data: JumpData
        let timestamp: Date
        let sessionId: UUID
    }
    
    func recordJump(_ jumpData: JumpData) {
        let record = JumpRecord(
            data: jumpData,
            timestamp: Date(),
            sessionId: currentSessionId
        )
        jumpHistory.append(record)
        saveToStorage()
    }
    
    private func saveToStorage() {
        // Implementar persistência
    }
}
```

### 2. Analytics e Métricas

```swift
extension JumpTrackerViewModel {
    var analytics: JumpAnalytics {
        JumpAnalytics(
            totalJumps: jumpHistory.count,
            averageHeight: jumpHistory.map(\.data.lastHeight).average,
            bestHeight: jumpData.bestHeight,
            improvement: calculateImprovement()
        )
    }
    
    private func calculateImprovement() -> Double {
        // Calcular melhoria ao longo do tempo
        guard jumpHistory.count >= 2 else { return 0 }
        
        let recent = jumpHistory.suffix(10).map(\.data.lastHeight).average
        let older = jumpHistory.prefix(10).map(\.data.lastHeight).average
        
        return ((recent - older) / older) * 100
    }
}
```

## 🔧 Customizações da UI

### 1. Interface Personalizada

```swift
struct CustomJumpDisplay: View {
    @StateObject private var viewModel = JumpTrackerViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header customizado
            Text("My Sports App")
                .font(.largeTitle)
                .bold()
            
            // Medições principais
            HStack(spacing: 40) {
                VStack {
                    Text("\(Int(viewModel.jumpData.lastHeightCM))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("ÚLTIMO")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(Int(viewModel.jumpData.bestHeightCM))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("MELHOR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status indicator
            StatusIndicator(isActive: viewModel.isActive)
        }
        .padding()
        .onAppear { viewModel.startDetection() }
        .onDisappear { viewModel.stopDetection() }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isActive ? .green : .red)
                .frame(width: 12, height: 12)
            
            Text(isActive ? "Detectando" : "Inativo")
                .font(.caption)
        }
    }
}
```

### 2. Animações e Feedback

```swift
struct AnimatedJumpDisplay: View {
    @StateObject private var viewModel = JumpTrackerViewModel()
    @State private var showingJumpAnimation = false
    
    var body: some View {
        VStack {
            Text(viewModel.lastJumpFormatted)
                .font(.title)
                .scaleEffect(showingJumpAnimation ? 1.2 : 1.0)
                .animation(.spring(response: 0.5), value: showingJumpAnimation)
        }
        .onReceive(NotificationCenter.default.publisher(for: .jumpDetected)) { _ in
            triggerJumpAnimation()
        }
    }
    
    private func triggerJumpAnimation() {
        showingJumpAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingJumpAnimation = false
        }
        
        // Haptic feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
}
```

## 🔍 Debug e Testes

### 1. Modo Debug

```swift
#if DEBUG
extension JumpDetector {
    func enableDebugMode() {
        // Ativar logs detalhados
        print("🔍 Debug mode ativado")
    }
    
    func simulateJump(height: Double) {
        DispatchQueue.main.async {
            self.lastJumpHeight = height
            self.bestJumpHeight = max(self.bestJumpHeight, height)
            NotificationCenter.default.post(name: .jumpDetected, object: nil)
        }
    }
}
#endif
```

### 2. Testes Unitários

```swift
import XCTest

class JumpDetectorTests: XCTestCase {
    
    func testJumpDataCalculation() {
        let jumpData = JumpData(
            lastHeight: 0.25,
            bestHeight: 0.35,
            timestamp: Date(),
            qualityScore: 7.5,
            flightTime: 0.35
        )
        
        XCTAssertEqual(jumpData.lastHeightCM, 25.0)
        XCTAssertEqual(jumpData.bestHeightCM, 35.0)
        XCTAssertTrue(jumpData.isValidJump)
    }
    
    func testConfiguration() {
        let config = JumpConfiguration.default
        
        XCTAssertEqual(config.freefallThreshold, 0.35)
        XCTAssertEqual(config.groundThreshold, 1.20)
        XCTAssertEqual(config.minJumpScore, 5.0)
    }
}
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Saltos não detectados**
   - Verificar se o threshold está muito alto
   - Confirmar que o device motion está disponível
   - Testar com saltos mais altos/longos

2. **Muitos falsos positivos**
   - Aumentar `minJumpScore`
   - Ajustar `needPreJumpStableSamples`
   - Verificar se há vibrações externas

3. **Medições inconsistentes**
   - Calibrar thresholds para o usuário específico
   - Verificar interferência de outros apps
   - Testar em ambiente controlado

### Validação do Sistema

```swift
extension JumpTrackerViewModel {
    func validateSystemHealth() -> SystemHealthReport {
        return SystemHealthReport(
            isMotionAvailable: jumpDetector.isMotionAvailable,
            isBarometerAvailable: jumpDetector.isBarometerAvailable,
            detectionAccuracy: calculateAccuracy(),
            batteryImpact: estimateBatteryImpact()
        )
    }
}
```

## 📈 Performance

### Otimizações Recomendadas

1. **Uso de Bateria**
   - Pare a detecção quando não necessário
   - Use `onAppear`/`onDisappear` adequadamente
   - Considere pausas automáticas

2. **Uso de Memória**
   - Buffers são limitados automaticamente
   - Histórico tem capacidade máxima
   - GC automático de dados antigos

3. **CPU**
   - Processamento otimizado para 100Hz
   - Filtros eficientes
   - Threading apropriado

---

**Pronto para integrar! 🚀**

Para dúvidas específicas, consulte a documentação completa ou analise o código de exemplo no projeto.

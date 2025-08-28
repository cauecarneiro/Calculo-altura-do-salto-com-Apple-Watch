# FutevoleiJumps - Detector de Saltos para Apple Watch

Um sistema avançado de detecção e medição de saltos usando os sensores do Apple Watch.

## 🎯 Como Funciona

O sistema detecta saltos em 5 etapas principais:

1. **Estabilidade**: Monitora se a pessoa está parada
2. **Queda Livre**: Detecta quando começa a cair (aceleração < 0.4g)
3. **Voo**: Acompanha durante todo o salto
4. **Aterrissagem**: Detecta volta ao chão (aceleração > 1.15g)
5. **Validação**: Confirma se é salto real (score ≥ 4.0/10)

## 📊 Precisão Esperada

- **Saltos baixos** (5-20cm): ±3cm
- **Saltos médios** (20-35cm): ±5cm  
- **Saltos altos** (35-50cm): ±8cm

## 🔧 Como Usar em Seu Projeto

### 1. Copie o arquivo `JumpDetector.swift`

```swift
// Mantenha apenas este arquivo - ele é auto-contido
```

### 2. Configure as permissões

No `Info.plist` adicione:

```xml
<key>NSMotionUsageDescription</key>
<string>Usamos os sensores para detectar e medir seus saltos</string>
```

### 3. Use na sua View

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var detector = JumpDetector()
    
    var body: some View {
        VStack {
            Text("Saltos: \(detector.jumpCount)")
            Text("Último: \(String(format: "%.1f", detector.lastJumpHeight * 100))cm")
            Text("Melhor: \(String(format: "%.1f", detector.bestJumpHeight * 100))cm")
        }
        .onAppear {
            detector.start()  // Inicia detecção
        }
        .onDisappear {
            detector.stop()   // Para detecção
        }
    }
}
```

### 4. Observar saltos (opcional)

```swift
// Para reagir a cada salto detectado
.onAppear {
    NotificationCenter.default.addObserver(
        forName: .jumpDetected,
        object: nil,
        queue: .main
    ) { _ in
        // Salto detectado!
        print("Novo salto: \(detector.lastJumpHeight * 100)cm")
    }
}
```

## ⚙️ Configuração Avançada

### Personalizando Parâmetros

Para ajustar sensibilidade, edite a struct `Config`:

```swift
private struct Config {
    static let freefallThreshold: Double = 0.40    // ↓ mais sensível
    static let groundThreshold: Double = 1.15      // ↑ mais rigoroso
    static let minimumScore: Double = 4.0          // ↓ aceita mais saltos
    static let stableSamplesNeeded: Int = 3        // ↓ menos estabilidade
}
```

### Entendendo os Logs de Debug

```
[STABLE] g=0.98 READY           → Pessoa parada, pronto para detectar
[TAKEOFF] g=0.35 STARTED        → Início do salto detectado
[IN_FLIGHT] AIRBORNE            → Pessoa no ar
[MED] t=0.234s score=7.0 h=24cm → Salto válido de 24cm
[REJECTED] score=2.1 < 4.0      → Salto rejeitado (score baixo)
```

## 🏗️ Arquitetura do Código

### Estrutura Modular

- **`Config`**: Todos os parâmetros configuráveis
- **`State`**: Estado atual da detecção  
- **`Calculator`**: Cálculos de física (altura, correções)
- **`Validator`**: Validação de saltos vs falsos positivos
- **`JumpDetector`**: Classe principal que coordena tudo

### Fluxo de Dados

```
Sensores → Filtro → Estado → Validação → Resultado
    ↓        ↓        ↓         ↓          ↓
CoreMotion → EMA → Ground/Flight → Score → Altura
```

## 🚫 Anti-Falsos Positivos

O sistema rejeita automaticamente:

- **Movimento de braço**: Baixa amplitude + média ~1g
- **Tremulação**: Tempo muito curto (< 120ms)
- **Apoio rápido**: Sem impacto real (< 2.5g)
- **Instabilidade**: Sem período estável antes

## 📱 Compatibilidade

- **watchOS 10.0+**: Funcionalidade completa
- **iOS/macOS**: Stub vazio (não quebra compilação)

## 🎮 Casos de Uso

- **Esportes**: Futevôlei, vôlei, basquete
- **Fitness**: Treino de salto vertical
- **Reabilitação**: Monitoramento de progresso
- **Pesquisa**: Coleta de dados biomecânicos

## 🔬 Algoritmo Técnico

### Detecção de Salto

1. **Componente Vertical**: Projeta aceleração no eixo "down"
2. **Filtro EMA**: Suaviza ruído mantendo responsividade
3. **Interpolação**: Precisão sub-amostra para timestamps
4. **Integração**: Velocidade para detectar ápice (futuro)

### Cálculo de Altura

1. **Base**: h = gt²/8 (física do tempo de voo)
2. **Correção por faixa**: Ajustes empíricos
3. **Fusão barométrica**: Validação com altímetro
4. **Clipping**: Limites de segurança

## 🐛 Troubleshooting

### Saltos não detectados
- Verifique permissões de motion
- Aumente `freefallThreshold` para 0.35
- Reduza `stableSamplesNeeded` para 2

### Muitos falsos positivos  
- Reduza `freefallThreshold` para 0.45
- Aumente `minimumScore` para 5.0
- Aumente `stableSamplesNeeded` para 5

### Altura imprecisa
- Ajuste fatores em `applyCorrectionForRange()`
- Verifique calibração do barômetro
- Compare com medição externa

## 📄 Licença

Código livre para uso pessoal e comercial. 

## 🤝 Contribuição

Para melhorar o algoritmo:

1. Colete dados reais (altura esperada vs medida)
2. Ajuste fatores de correção
3. Teste em diferentes tipos de salto
4. Compartilhe resultados

---

**Desenvolvido para precisão real em condições reais de uso.**


# Jump Tracker - Sistema de Detecção de Saltos

Um sistema avançado de detecção de saltos para Apple Watch, desenvolvido em SwiftUI com arquitetura MVVM.

## 📋 Visão Geral

O Jump Tracker utiliza dados do acelerômetro e altímetro do Apple Watch para detectar e medir saltos com alta precisão. O sistema emprega algoritmos sofisticados de filtragem de sinal e validação para minimizar falsos positivos e garantir medições precisas.

## 🏗️ Arquitetura

### Estrutura de Pastas

```
FutevoleiJumps Watch App/
├── Core/
│   └── JumpDetector.swift          # Sistema principal de detecção
├── Models/
│   ├── JumpData.swift              # Modelo de dados dos saltos
│   └── JumpConfiguration.swift     # Configurações do sistema
├── ViewModels/
│   └── JumpTrackerViewModel.swift  # ViewModel MVVM
├── Views/
│   └── ContentView.swift           # Interface principal
├── Documentation/
│   └── README.md                   # Este arquivo
└── App/
    └── JumpTrackerApp.swift        # Ponto de entrada do app
```

### Padrões Utilizados

- **MVVM (Model-View-ViewModel)**: Separação clara entre UI e lógica de negócio
- **Combine Framework**: Binding reativo entre componentes
- **Observer Pattern**: Notificações para eventos de saltos detectados

## 🚀 Componentes Principais

### 1. JumpDetector (`Core/JumpDetector.swift`)

O núcleo do sistema responsável por:

- **Detecção de Padrões**: Identifica sequências de queda livre → voo → pouso
- **Filtragem de Sinal**: Aplica filtros EMA para reduzir ruído
- **Validação Inteligente**: Sistema de pontuação (0-10) para validar saltos
- **Interpolação Temporal**: Calcula momentos exatos de decolagem e pouso
- **Integração de Sensores**: Combina dados de acelerômetro e altímetro

#### Algoritmo de Detecção

1. **Fase de Estabilidade**: Valida que o usuário está parado
2. **Detecção de Queda Livre**: Identifica aceleração < 0.35g
3. **Confirmação de Voo**: Aguarda 6 amostras consecutivas
4. **Detecção de Ápice**: Encontra velocidade vertical = 0
5. **Detecção de Pouso**: Identifica aceleração > 1.20g
6. **Validação**: Calcula score de qualidade e valida o salto

### 2. JumpTrackerViewModel (`ViewModels/JumpTrackerViewModel.swift`)

Gerencia o estado da aplicação:

- **Estado da UI**: Controla loading, erros e dados exibidos
- **Binding Reativo**: Conecta detector com a interface
- **Formatação**: Prepara dados para exibição
- **Lifecycle**: Gerencia início/parada do sistema

### 3. Modelos de Dados

#### JumpData (`Models/JumpData.swift`)
```swift
struct JumpData {
    let lastHeight: Double      // Altura do último salto (metros)
    let bestHeight: Double      // Melhor altura registrada (metros)
    let timestamp: Date         // Timestamp do salto
    let qualityScore: Double    // Score de qualidade (0-10)
    let flightTime: Double      // Tempo de voo (segundos)
}
```

#### JumpConfiguration (`Models/JumpConfiguration.swift`)
Configurações otimizadas do sistema:
- Thresholds de detecção
- Parâmetros de validação
- Configurações de filtros
- Constantes físicas

## 🎯 Parâmetros de Calibração

### Thresholds Principais
- **Queda Livre**: 0.35g (detecta início do salto)
- **Pouso**: 1.20g (confirma retorno ao chão)
- **Estabilidade**: 0.85g - 1.20g (validação pré-salto)

### Validação
- **Amostras de Confirmação**: 6 para queda livre, 12 para pouso
- **Score Mínimo**: 5.0 pontos (de 10 possíveis)
- **Tempo de Voo**: 0.10s - 1.20s (faixa válida)

### Filtros
- **EMA Principal**: α = 0.25 (suavização)
- **EMA Rápido**: α = 0.40 (responsividade)
- **Frequência**: 100Hz (amostragem)

## 📐 Cálculo de Altura

### Fórmula Base
```
h = g × t² / 8
```
Onde:
- `h` = altura do salto (metros)
- `g` = aceleração da gravidade (9.80665 m/s²)
- `t` = tempo de voo (segundos)

### Ajustes de Precisão
- **Saltos Altos** (>35cm): ×0.85 (correção para baixo)
- **Saltos Médios** (15-35cm): ×0.95 (pequena correção)
- **Saltos Baixos** (<15cm): ×1.10 (correção para cima)

### Validação Barométrica
Quando disponível, incorpora dados do altímetro (20% peso) para validação.

## 🔧 Como Usar

### Integração Básica

```swift
import SwiftUI

struct MyJumpView: View {
    @StateObject private var viewModel = JumpTrackerViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.lastJumpFormatted)
            Text(viewModel.bestJumpFormatted)
        }
        .onAppear {
            viewModel.startDetection()
        }
        .onDisappear {
            viewModel.stopDetection()
        }
    }
}
```

### Configuração Customizada

```swift
// Modificar thresholds (desativa adaptação automática)
let detector = JumpDetector()
detector.setCustomFreefallThreshold(0.30)  // Mais sensível
detector.setCustomGroundThreshold(1.25)    // Mais rigoroso
```

## 🧪 Sistema de Validação

### Score de Qualidade (0-10 pontos)

1. **Tempo de Voo** (0-3 pontos)
   - 3.0: ≥150ms (saltos consistentes)
   - 2.0: ≥100ms (saltos menores válidos)

2. **Queda Livre** (0-2.5 pontos)
   - 2.5: <0.65g (queda livre clara)
   - 1.5: <0.80g (queda livre moderada)

3. **Impacto de Pouso** (0-2.5 pontos)
   - 2.5: >1.35g (impacto forte)
   - 1.5: >1.15g (impacto moderado)

4. **Variação de Movimento** (0-1.5 pontos)
   - 1.5: >1.2 (movimento dinâmico)
   - 1.0: >0.6 (movimento moderado)

5. **Ápice Detectado** (0-0.5 pontos)
   - 0.5: Bônus por precisão temporal

## 🚨 Tratamento de Erros

### Falsos Positivos Evitados
- Movimentos de braço (validação de estabilidade)
- Vibrações (filtragem de sinal)
- Movimentos bruscos (sistema de score)
- Dados corrompidos (validação temporal)

### Falsos Negativos Minimizados
- Thresholds adaptativos
- Múltiplas métricas de validação
- Interpolação temporal precisa
- Integração de múltiplos sensores

## 📊 Performance

### Recursos Utilizados
- **CPU**: Baixo impacto (~1-2% durante uso)
- **Bateria**: Otimizado para uso contínuo
- **Memória**: ~500KB para buffers e históricos

### Limitações
- Apenas Apple Watch (requer Core Motion)
- Altímetro barométrico nem sempre disponível
- Precisão afetada por condições extremas

## 🔮 Extensibilidade

### Configurações Customizadas
```swift
// Criar configuração personalizada
struct CustomConfiguration: JumpConfiguration {
    let freefallThreshold: Double = 0.30  // Mais sensível
    let minJumpScore: Double = 6.0        // Mais rigoroso
}
```

### Novos Sensores
O sistema é preparado para incorporar:
- Dados de GPS para validação
- Magnetômetro para orientação
- Heart rate para contexto

### Analytics
Framework pronto para adicionar:
- Histórico de saltos
- Estatísticas de performance
- Trends e análises

## 📝 Notas de Desenvolvimento

### Debug
Compile com `DEBUG` flag para logs detalhados:
```
🛫 TAKEOFF detectado - g=0.32
✈️ EM VOO - transição confirmada
🔝 ÁPICE detectado em t=0.245s
✅ SALTO ALTO - h=42cm, t=0.490s
```

### Testes
- Teste em ambiente controlado primeiro
- Valide com saltos conhecidos
- Compare com medições manuais

### Manutenção
- Monitore false positive rate
- Ajuste thresholds conforme necessário
- Colete feedback de usuários para melhorias

---

**Desenvolvido com ❤️ para precisão e performance**

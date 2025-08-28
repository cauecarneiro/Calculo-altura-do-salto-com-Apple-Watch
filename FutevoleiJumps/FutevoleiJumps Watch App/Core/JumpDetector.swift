//
//  JumpDetector.swift
//  Jump Tracker Watch App
//
//  Sistema principal de detecção de saltos usando acelerômetro e altímetro
//  Algoritmo otimizado para precisão e redução de falsos positivos
//

#if os(watchOS)

import Foundation
import CoreMotion
import Combine

// MARK: - Jump Detector

/// Detector de saltos usando dados do acelerômetro e altímetro do Apple Watch
/// 
/// Este sistema utiliza um algoritmo sofisticado que:
/// - Detecta padrões de queda livre para identificar o início do salto
/// - Calcula o tempo de voo com precisão usando interpolação
/// - Valida saltos através de um sistema de pontuação inteligente
/// - Aplica filtros para reduzir ruído e falsos positivos
final class JumpDetector: ObservableObject {
    
    // MARK: - Published Properties (Interface com UI)
    
    /// Altura do último salto detectado (em metros)
    @Published var lastJumpHeight: Double = 0.0
    
    /// Maior altura já registrada (em metros)
    @Published var bestJumpHeight: Double = 0.0
    
    // MARK: - Core Motion Components
    
    /// Gerenciador principal do Core Motion
    private let motionManager = CMMotionManager()
    
    /// Fila de operações para processamento em background
    private let operationQueue = OperationQueue()
    
    /// Altímetro para medição barométrica (quando disponível)
    private let altimeter = CMAltimeter()
    
    /// Indica se o altímetro barométrico está disponível
    private var isBarometerAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    
    // MARK: - Configuration
    
    /// Configurações do sistema de detecção
    private let config = JumpConfiguration.default
    
    // MARK: - State Management
    
    /// Indica se o sistema está atualmente detectando um salto em voo
    private var isInFlight = false
    
    /// Timestamp do momento de decolagem (início do salto)
    private var takeoffTime: TimeInterval?
    
    /// Timestamp candidato para o pouso (pode ser ajustado)
    private var landingCandidateTime: TimeInterval?
    
    /// Timestamp do ápice do salto (ponto mais alto)
    private var apexTime: TimeInterval?
    
    /// Indica se o ápice foi encontrado durante o voo atual
    private var apexDetected = false
    
    // MARK: - Sensor Data Processing
    
    /// Velocidade vertical integrada (m/s)
    private var verticalVelocity: Double = 0.0
    
    /// Histórico recente de aceleração para detecção de picos de impacto
    private var recentAccelerationData: [Double] = []
    
    /// Capacidade máxima do buffer de aceleração
    private let accelerationBufferCapacity = 64
    
    /// Histórico de velocidades para validação
    private var velocityHistory: [Double] = []
    
    /// Capacidade máxima do histórico de velocidades
    private let velocityHistoryCapacity = 10
    
    // MARK: - Signal Filtering
    
    /// Valor filtrado da aceleração (filtro EMA principal)
    private var filteredAcceleration: Double = 1.0
    
    /// Valor menos filtrado para detecção rápida
    private var fastFilteredAcceleration: Double = 1.0
    
    /// Aceleração da amostra anterior (para interpolação)
    private var previousAcceleration: Double = 1.0
    
    /// Timestamp da amostra anterior
    private var previousTimestamp: TimeInterval = 0
    
    /// Aceleração da amostra atual
    private var currentAcceleration: Double = 1.0
    
    /// Timestamp da amostra atual
    private var currentTimestamp: TimeInterval = 0
    
    /// Flag para identificar a primeira amostra
    private var isFirstSample = true
    
    // MARK: - Validation Counters
    
    /// Contador de amostras consecutivas abaixo do threshold de queda livre
    private var freefallSampleCount = 0
    
    /// Contador de amostras consecutivas acima do threshold de pouso
    private var groundContactSampleCount = 0
    
    /// Contador de amostras estáveis antes do salto
    private var preJumpStabilityCount = 0
    
    // MARK: - Jump Validation Metrics
    
    /// Pontuação de qualidade do salto atual (0-10)
    private var currentJumpScore: Double = 0.0
    
    /// Variação total de aceleração durante o voo
    private var totalAccelerationVariation: Double = 0.0
    
    /// Menor valor de aceleração registrado durante o voo
    private var minimumFlightAcceleration: Double = 1.0
    
    /// Maior valor de aceleração registrado durante o pouso
    private var maximumLandingAcceleration: Double = 0.0
    
    /// Histórico recente para detecção de movimentos espúrios
    private var recentAccelerationHistory: [Double] = []
    
    /// Capacidade do histórico recente
    private let recentHistoryCapacity = 20
    
    // MARK: - Adaptive Baseline (para auto-calibração)
    
    /// Média adaptativa da linha de base
    private var adaptiveBaseline: Double = 1.0
    
    /// Variância acumulada para cálculo estatístico
    private var baselineVarianceAccumulator: Double = 0.0
    
    /// Contador de amostras para baseline
    private var baselineSampleCount: Int = 0
    
    /// Flag para usar thresholds adaptativos
    private var useAdaptiveThresholds = true
    
    // MARK: - Barometer Data
    
    /// Altitude barométrica atual (relativa ao início da sessão)
    private var currentBarometricAltitude: Double = 0.0
    
    /// Altitude no início do voo atual
    private var flightStartBarometricAltitude: Double = 0.0
    
    /// Altitude máxima durante o voo atual
    private var maximumFlightBarometricAltitude: Double = 0.0
    
    // MARK: - Public API
    
    /// Inicia o sistema de detecção de saltos
    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device Motion não está disponível neste dispositivo")
            return
        }
        
        resetSystemState()
        startMotionUpdates()
        
        if isBarometerAvailable {
            startBarometerUpdates()
        }
        
        print("🚀 Sistema de detecção de saltos iniciado")
    }
    
    /// Para o sistema de detecção de saltos
    func stop() {
        motionManager.stopDeviceMotionUpdates()
        
        if isBarometerAvailable {
            altimeter.stopRelativeAltitudeUpdates()
        }
        
        print("⏹️ Sistema de detecção de saltos parado")
    }
    
    // MARK: - Configuration Methods
    
    /// Define threshold de queda livre customizado (desativa adaptação automática)
    func setCustomFreefallThreshold(_ threshold: Double) {
        useAdaptiveThresholds = false
        // Note: O threshold será aplicado na próxima atualização
    }
    
    /// Define threshold de pouso customizado (desativa adaptação automática)
    func setCustomGroundThreshold(_ threshold: Double) {
        useAdaptiveThresholds = false
        // Note: O threshold será aplicado na próxima atualização
    }
    
    // MARK: - Private Methods - System Setup
    
    /// Configura e inicia as atualizações do motion manager
    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 1.0 / config.updateFrequency
        
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: operationQueue
        ) { [weak self] deviceMotion, error in
            guard let self = self, let motion = deviceMotion else {
                if let error = error {
                    print("❌ Erro no Device Motion: \(error.localizedDescription)")
                }
                return
            }
            
            self.processDeviceMotion(motion)
        }
    }
    
    /// Configura e inicia as atualizações do altímetro
    private func startBarometerUpdates() {
        altimeter.startRelativeAltitudeUpdates(to: OperationQueue()) { [weak self] data, error in
            guard let self = self, let altitudeData = data else {
                if let error = error {
                    print("❌ Erro no altímetro: \(error.localizedDescription)")
                }
                return
            }
            
            self.currentBarometricAltitude = altitudeData.relativeAltitude.doubleValue
        }
    }
    
    // MARK: - Private Methods - Data Processing
    
    /// Processa os dados de movimento do dispositivo
    /// Este é o método principal que analisa cada amostra do acelerômetro
    private func processDeviceMotion(_ deviceMotion: CMDeviceMotion) {
        // 1. Extrai a componente vertical da aceleração
        let verticalAcceleration = extractVerticalAcceleration(from: deviceMotion)
        
        // 2. Aplica filtros para suavizar o sinal
        applySignalFiltering(verticalAcceleration, timestamp: deviceMotion.timestamp)
        
        // 3. Atualiza buffers e históricos
        updateDataBuffers()
        
        // 4. Atualiza baseline adaptativo quando não está em voo
        updateAdaptiveBaseline()
        
        // 5. Processa lógica principal de detecção
        if isInFlight {
            processInFlightLogic()
        } else {
            processGroundLogic()
        }
    }
    
    /// Extrai a componente vertical da aceleração total (incluindo gravidade)
    /// Retorna a aceleração em unidades de 'g' (9.8 m/s²)
    private func extractVerticalAcceleration(from deviceMotion: CMDeviceMotion) -> Double {
        // Vetor de gravidade normalizado (direção "para baixo")
        let gravity = deviceMotion.gravity
        let gravityMagnitude = max(1e-9, sqrt(gravity.x * gravity.x + gravity.y * gravity.y + gravity.z * gravity.z))
        let downDirection = (
            x: gravity.x / gravityMagnitude,
            y: gravity.y / gravityMagnitude,
            z: gravity.z / gravityMagnitude
        )
        
        // Aceleração total (user + gravity)
        let totalAcceleration = (
            x: deviceMotion.userAcceleration.x + gravity.x,
            y: deviceMotion.userAcceleration.y + gravity.y,
            z: deviceMotion.userAcceleration.z + gravity.z
        )
        
        // Projeção da aceleração total na direção da gravidade
        return totalAcceleration.x * downDirection.x +
               totalAcceleration.y * downDirection.y +
               totalAcceleration.z * downDirection.z
    }
    
    /// Aplica filtros EMA (Exponential Moving Average) para suavizar o sinal
    private func applySignalFiltering(_ rawAcceleration: Double, timestamp: TimeInterval) {
        if isFirstSample {
            // Inicializa todos os valores na primeira amostra
            filteredAcceleration = rawAcceleration
            fastFilteredAcceleration = rawAcceleration
            previousAcceleration = rawAcceleration
            previousTimestamp = timestamp
            currentAcceleration = rawAcceleration
            currentTimestamp = timestamp
            isFirstSample = false
            return
        }
        
        // Atualiza valores anteriores
        previousAcceleration = currentAcceleration
        previousTimestamp = currentTimestamp
        
        // Aplica filtros EMA
        filteredAcceleration = config.alphaFilter * rawAcceleration + (1 - config.alphaFilter) * filteredAcceleration
        fastFilteredAcceleration = config.alphaFastFilter * rawAcceleration + (1 - config.alphaFastFilter) * fastFilteredAcceleration
        
        // Atualiza valores atuais
        currentAcceleration = filteredAcceleration
        currentTimestamp = timestamp
    }
    
    /// Atualiza os buffers de dados para análise
    private func updateDataBuffers() {
        // Buffer de aceleração para detecção de picos de impacto
        recentAccelerationData.append(currentAcceleration)
        if recentAccelerationData.count > accelerationBufferCapacity {
            recentAccelerationData.removeFirst()
        }
        
        // Histórico recente para detecção de movimentos espúrios
        recentAccelerationHistory.append(currentAcceleration)
        if recentAccelerationHistory.count > recentHistoryCapacity {
            recentAccelerationHistory.removeFirst()
        }
    }
    
    // MARK: - Private Methods - Ground Logic
    
    /// Processa a lógica quando o usuário está no chão (não em voo)
    private func processGroundLogic() {
        // Validação de estabilidade pré-salto
        validatePreJumpStability()
        
        // Detecção do início de queda livre
        detectFreefallStart()
        
        // Transição para estado de voo se condições forem atendidas
        checkFlightTransition()
    }
    
    /// Valida se o usuário está estável antes de permitir detecção de salto
    private func validatePreJumpStability() {
        if currentAcceleration >= config.stableMinG && currentAcceleration <= config.stableMaxG {
            preJumpStabilityCount += 1
        } else {
            // Decay mais rigoroso para garantir estabilidade real
            preJumpStabilityCount = max(0, preJumpStabilityCount - 2)
        }
    }
    
    /// Detecta o início da queda livre (takeoff)
    private func detectFreefallStart() {
        // Só permite detecção se houve estabilidade suficiente ou já está detectando
        guard preJumpStabilityCount >= config.needPreJumpStableSamples || freefallSampleCount > 0 else {
            freefallSampleCount = 0
            takeoffTime = nil
            return
        }
        
        if currentAcceleration < config.freefallThreshold {
            freefallSampleCount += 1
            
            // Marca o primeiro momento de queda livre
            if freefallSampleCount == 1 {
                takeoffTime = interpolateCrossingTime(
                    threshold: config.freefallThreshold,
                    direction: .downward
                )
                
                // Inicializa métricas do salto
                initializeJumpMetrics()
                
                #if DEBUG
                print("🛫 TAKEOFF detectado - g=\(String(format: "%.2f", currentAcceleration))")
                #endif
            }
        } else {
            // Reset se perdeu o padrão de queda livre
            freefallSampleCount = 0
            takeoffTime = nil
        }
    }
    
    /// Verifica se deve transicionar para estado de voo
    private func checkFlightTransition() {
        guard freefallSampleCount >= config.needBelowFreefallSamples,
              takeoffTime != nil else { return }
        
        // Transição para estado de voo
        isInFlight = true
        groundContactSampleCount = 0
        landingCandidateTime = nil
        
        // Limpa buffer de impacto para o novo voo
        recentAccelerationData.removeAll(keepingCapacity: true)
        
        #if DEBUG
        print("✈️ EM VOO - transição confirmada")
        #endif
    }
    
    // MARK: - Private Methods - Flight Logic
    
    /// Processa a lógica durante o voo
    private func processInFlightLogic() {
        // Atualiza métricas do voo
        updateFlightMetrics()
        
        // Integra velocidade vertical
        integrateVerticalVelocity()
        
        // Detecta ápice do salto
        detectApex()
        
        // Detecta pouso
        detectLanding()
        
        // Atualiza dados barométricos
        updateBarometricData()
        
        // Verifica finalização do salto
        checkJumpCompletion()
    }
    
    /// Atualiza métricas coletadas durante o voo
    private func updateFlightMetrics() {
        totalAccelerationVariation += abs(currentAcceleration - previousAcceleration)
        minimumFlightAcceleration = min(minimumFlightAcceleration, currentAcceleration)
        
        if currentAcceleration > config.groundThreshold {
            maximumLandingAcceleration = max(maximumLandingAcceleration, currentAcceleration)
        }
    }
    
    /// Integra a aceleração para calcular velocidade vertical
    private func integrateVerticalVelocity() {
        let deltaTime = currentTimestamp - previousTimestamp
        
        // Integra (aceleração - 1g) para obter velocidade
        verticalVelocity += (currentAcceleration - 1.0) * config.standardGravity * deltaTime
        
        // Atualiza histórico de velocidades
        velocityHistory.append(verticalVelocity)
        if velocityHistory.count > velocityHistoryCapacity {
            velocityHistory.removeFirst()
        }
        
        // Limita deriva excessiva
        if abs(verticalVelocity) > 6.0 {
            verticalVelocity = verticalVelocity > 0 ? 6.0 : -6.0
        }
    }
    
    /// Detecta o ápice do salto (quando velocidade vertical cruza zero) com algoritmo melhorado
    private func detectApex() {
        guard !apexDetected else { return }
        
        let deltaTime = currentTimestamp - previousTimestamp
        let previousVelocity = verticalVelocity - (currentAcceleration - 1.0) * config.standardGravity * deltaTime
        
        // Verifica cruzamento de zero na velocidade com tolerância melhorada
        let crossedZero = previousVelocity < -0.05 && verticalVelocity >= -0.03
        
        // Validação mais flexível do tempo de voo
        let timeInFlight = currentTimestamp - (takeoffTime ?? currentTimestamp)
        let reasonableTime = timeInFlight > 0.08 && timeInFlight < 1.0
        
        // Validação adicional: velocidade deve estar desacelerando
        let velocityTrend = velocityHistory.suffix(3)
        let isDecelerating = velocityTrend.count >= 2 && 
                           velocityTrend.last! > velocityTrend.dropLast().last!
        
        if crossedZero && reasonableTime && (isDecelerating || velocityHistory.count < 3) {
            // Interpola o momento exato do ápice com melhor precisão
            let fraction = abs(verticalVelocity) / (abs(verticalVelocity) + abs(previousVelocity) + 0.001)
            let clampedFraction = max(0.0, min(1.0, fraction))
            apexTime = currentTimestamp - clampedFraction * deltaTime
            apexDetected = true
            
            #if DEBUG
            print("🔝 ÁPICE detectado em t=\(String(format: "%.3f", timeInFlight))s v=\(String(format: "%.2f", verticalVelocity))")
            #endif
        }
    }
    
    /// Detecta o contato com o chão (landing)
    private func detectLanding() {
        if currentAcceleration > config.groundThreshold {
            groundContactSampleCount += 1
            
            // Marca o primeiro momento de contato
            if groundContactSampleCount == 1 {
                landingCandidateTime = interpolateCrossingTime(
                    threshold: config.groundThreshold,
                    direction: .upward
                )
            }
        } else {
            groundContactSampleCount = 0
            landingCandidateTime = nil
        }
    }
    
    /// Atualiza dados barométricos durante o voo
    private func updateBarometricData() {
        guard isBarometerAvailable else { return }
        
        if currentBarometricAltitude > maximumFlightBarometricAltitude {
            maximumFlightBarometricAltitude = currentBarometricAltitude
        }
    }
    
    /// Verifica se o salto está completo e deve ser processado
    private func checkJumpCompletion() {
        guard groundContactSampleCount >= config.needAboveGroundSamples,
              let startTime = takeoffTime,
              let endTime = landingCandidateTime else { return }
        
        // Calcula o tempo de voo
        var flightTime = endTime - startTime
        
        // Ajusta usando tempo do ápice se disponível e confiável
        if let apexTime = apexTime {
            let apexBasedFlightTime = 2.0 * max(0.0, apexTime - startTime)
            if apexBasedFlightTime > 0 && apexBasedFlightTime < flightTime * 1.5 {
                flightTime = apexBasedFlightTime
            }
        }
        
        // Valida tempo de voo
        guard flightTime >= config.minFlightTime && flightTime <= config.maxFlightTime else {
            resetFlightState()
            return
        }
        
        // Verifica impacto e calcula score de qualidade
        let impactForce = recentAccelerationData.suffix(config.impactWindowSamples).max() ?? 0.0
        let impactDetected = impactForce >= config.impactPeakG || apexDetected
        
        currentJumpScore = calculateJumpQualityScore(
            flightTime: flightTime,
            minimumG: minimumFlightAcceleration,
            maximumG: maximumLandingAcceleration,
            variation: totalAccelerationVariation,
            impact: impactForce,
            apexFound: apexDetected
        )
        
        // Valida se é um salto legítimo
        if currentJumpScore >= config.minJumpScore {
            processValidJump(flightTime: flightTime)
        } else {
            #if DEBUG
            print("❌ SALTO REJEITADO - Score: \(String(format: "%.1f", currentJumpScore))")
            #endif
            resetFlightState()
        }
    }
    
    // MARK: - Private Methods - Jump Processing
    
    /// Processa um salto válido e calcula a altura com algoritmo aprimorado
    private func processValidJump(flightTime: Double) {
        // Calcula altura base usando fórmula cinemática: h = g*t²/8
        var calculatedHeight = config.standardGravity * flightTime * flightTime / 8.0
        
        // Melhoria: Usar dados do ápice se disponível para correção
        if let apexTime = apexTime, let takeoffTime = takeoffTime {
            let apexFlightTime = 2.0 * (apexTime - takeoffTime)
            if apexFlightTime > 0 && apexFlightTime <= flightTime * 1.3 {
                // Média ponderada entre tempo total e tempo do ápice
                let weightedTime = 0.7 * flightTime + 0.3 * apexFlightTime
                calculatedHeight = config.standardGravity * weightedTime * weightedTime / 8.0
            }
        }
        
        // Ajuste baseado na qualidade da detecção
        let qualityMultiplier = 0.95 + 0.1 * (currentJumpScore / 10.0)
        calculatedHeight *= qualityMultiplier
        
        // Aplica ajustes baseados na altura para maior precisão
        calculatedHeight = applyHeightAdjustments(calculatedHeight)
        
        // Incorpora dados barométricos se disponíveis
        calculatedHeight = incorporateBarometricData(calculatedHeight)
        
        // Garantir que a altura é positiva e realística
        calculatedHeight = max(0.02, min(2.0, calculatedHeight))
        
        // Atualiza dados na thread principal
        DispatchQueue.main.async { [weak self] in
            self?.updateJumpData(height: calculatedHeight)
        }
        
        #if DEBUG
        let jumpType = calculatedHeight >= 0.30 ? "ALTO" : calculatedHeight >= 0.20 ? "MÉDIO" : "BAIXO"
        print("✅ SALTO \(jumpType) - h=\(String(format: "%.0f", calculatedHeight * 100))cm, t=\(String(format: "%.3f", flightTime))s, score=\(String(format: "%.1f", currentJumpScore))")
        #endif
        
        resetFlightState()
    }
    
    /// Aplica ajustes na altura baseados em padrões observados e calibração otimizada
    private func applyHeightAdjustments(_ rawHeight: Double) -> Double {
        var adjustedHeight = rawHeight
        
        // Sistema de calibração mais preciso e escalonado
        if rawHeight >= 0.50 {
            // Saltos muito altos (50cm+) - ajuste conservador
            adjustedHeight *= 0.88
        } else if rawHeight >= 0.35 {
            // Saltos altos (35-50cm) - ajuste moderado
            adjustedHeight *= 0.92
        } else if rawHeight >= 0.20 {
            // Saltos médios (20-35cm) - ajuste leve
            adjustedHeight *= 0.97
        } else if rawHeight >= 0.10 {
            // Saltos baixos (10-20cm) - ajuste mínimo
            adjustedHeight *= 1.02
        } else {
            // Saltos muito baixos (<10cm) - aumenta um pouco
            adjustedHeight *= 1.15
        }
        
        // Aplicar correção adicional baseada na qualidade do salto
        let qualityFactor = min(1.0, currentJumpScore / config.minJumpScore)
        if qualityFactor > 0.8 {
            // Saltos de alta qualidade são mais confiáveis
            adjustedHeight *= (0.98 + 0.02 * qualityFactor)
        }
        
        return adjustedHeight
    }
    
    /// Incorpora dados barométricos para validação/correção
    private func incorporateBarometricData(_ calculatedHeight: Double) -> Double {
        guard isBarometerAvailable else { return calculatedHeight }
        
        let barometricHeight = max(0.0, maximumFlightBarometricAltitude - flightStartBarometricAltitude)
        
        // Usa barômetro apenas se os dados fizerem sentido
        if barometricHeight > 0.08 && barometricHeight < 1.0 && abs(barometricHeight - calculatedHeight) < 0.3 {
            // Combina 80% acelerômetro + 20% barômetro
            return 0.8 * calculatedHeight + 0.2 * barometricHeight
        }
        
        return calculatedHeight
    }
    
    /// Atualiza os dados do salto na UI
    private func updateJumpData(height: Double) {
        lastJumpHeight = height
        bestJumpHeight = max(bestJumpHeight, height)
        
        // Envia notificação para outros componentes
        NotificationCenter.default.post(name: .jumpDetected, object: nil)
    }
    
    // MARK: - Private Methods - Utility
    
    /// Interpola o momento exato de cruzamento de um threshold
    private func interpolateCrossingTime(threshold: Double, direction: CrossingDirection) -> Double {
        let denominator = currentAcceleration - previousAcceleration
        guard abs(denominator) >= 1e-9 else { return currentTimestamp }
        
        let fraction = (threshold - previousAcceleration) / denominator
        let clampedFraction = max(0.0, min(1.0, fraction))
        
        return previousTimestamp + clampedFraction * (currentTimestamp - previousTimestamp)
    }
    
    /// Calcula score de qualidade do salto (0-10 pontos) com algoritmo otimizado
    private func calculateJumpQualityScore(
        flightTime: Double,
        minimumG: Double,
        maximumG: Double,
        variation: Double,
        impact: Double,
        apexFound: Bool
    ) -> Double {
        var score: Double = 0.0
        
        // 1. Tempo de voo (0-3.5 pontos) - Mais peso e graduação
        if flightTime >= 0.20 {
            score += 3.5
        } else if flightTime >= 0.15 {
            score += 3.0
        } else if flightTime >= 0.12 {
            score += 2.5
        } else if flightTime >= 0.10 {
            score += 2.0
        } else if flightTime >= 0.08 {
            score += 1.5
        }
        
        // 2. Queda livre (0-2.5 pontos) - Mais permissivo mas graduado
        if minimumG < 0.60 {
            score += 2.5
        } else if minimumG < 0.70 {
            score += 2.0
        } else if minimumG < 0.80 {
            score += 1.5
        } else if minimumG < 0.90 {
            score += 1.0
        }
        
        // 3. Retorno ao chão (0-2.5 pontos) - Graduação mais inteligente
        if maximumG > 1.40 {
            score += 2.5
        } else if maximumG > 1.25 {
            score += 2.0
        } else if maximumG > 1.15 {
            score += 1.5
        } else if maximumG > 1.05 {
            score += 1.0
        }
        
        // 4. Variação de movimento (0-1.0 pontos) - Menos peso
        if variation > 1.0 {
            score += 1.0
        } else if variation > 0.5 {
            score += 0.7
        } else if variation > 0.3 {
            score += 0.5
        }
        
        // 5. Ápice detectado (0-0.5 pontos) - Bônus de precisão
        if apexFound {
            score += 0.5
        }
        
        // 6. Bônus por padrão consistente (0-0.5 pontos)
        let flightRatio = flightTime / 0.5 // Normaliza para 500ms
        let gRange = maximumG - minimumG
        if gRange > 0.8 && flightRatio > 0.2 && flightRatio < 2.0 {
            score += 0.5
        }
        
        return score
    }
    
    /// Atualiza baseline adaptativo para auto-calibração
    private func updateAdaptiveBaseline() {
        guard !isInFlight && useAdaptiveThresholds else { return }
        
        // Só considera valores estáveis para o baseline
        if currentAcceleration > 0.7 && currentAcceleration < 1.3 {
            baselineSampleCount += 1
            let delta = currentAcceleration - adaptiveBaseline
            adaptiveBaseline += delta / Double(baselineSampleCount)
            baselineVarianceAccumulator += delta * (currentAcceleration - adaptiveBaseline)
            
            // Aplica adaptação após coletar amostras suficientes
            if baselineSampleCount > 50 {
                let variance = baselineVarianceAccumulator / Double(baselineSampleCount - 1)
                let standardDeviation = sqrt(max(variance, 1e-6))
                
                // Ajusta thresholds baseado na baseline observada
                let adaptiveGroundThreshold = clamp(adaptiveBaseline + 0.15, 1.10, 1.30)
                let adaptiveFreefallThreshold = clamp(adaptiveBaseline - 4.0 * standardDeviation, 0.30, 0.40)
                
                // Aqui os thresholds adaptativos seriam aplicados (implementação futura)
            }
        }
    }
    
    /// Inicializa métricas para um novo salto
    private func initializeJumpMetrics() {
        verticalVelocity = 0
        apexDetected = false
        apexTime = nil
        flightStartBarometricAltitude = currentBarometricAltitude
        maximumFlightBarometricAltitude = currentBarometricAltitude
        totalAccelerationVariation = 0.0
        minimumFlightAcceleration = currentAcceleration
        maximumLandingAcceleration = 0.0
        currentJumpScore = 0.0
    }
    
    /// Reseta o estado do sistema
    private func resetSystemState() {
        resetFlightState()
        
        // Reset de filtros e buffers
        filteredAcceleration = 1.0
        fastFilteredAcceleration = 1.0
        previousAcceleration = 1.0
        currentAcceleration = 1.0
        previousTimestamp = 0
        currentTimestamp = 0
        isFirstSample = true
        
        // Reset de contadores
        preJumpStabilityCount = 0
        freefallSampleCount = 0
        groundContactSampleCount = 0
        
        // Reset de baseline adaptativo
        adaptiveBaseline = 1.0
        baselineVarianceAccumulator = 0.0
        baselineSampleCount = 0
        
        // Reset de dados barométricos
        currentBarometricAltitude = 0.0
        flightStartBarometricAltitude = 0.0
        maximumFlightBarometricAltitude = 0.0
        
        // Limpa todos os buffers
        recentAccelerationData.removeAll(keepingCapacity: true)
        recentAccelerationHistory.removeAll(keepingCapacity: true)
        velocityHistory.removeAll(keepingCapacity: true)
    }
    
    /// Reseta apenas o estado de voo
    private func resetFlightState() {
        isInFlight = false
        takeoffTime = nil
        landingCandidateTime = nil
        apexTime = nil
        apexDetected = false
        verticalVelocity = 0
        velocityHistory.removeAll(keepingCapacity: true)
        totalAccelerationVariation = 0.0
        minimumFlightAcceleration = 1.0
        maximumLandingAcceleration = 0.0
        currentJumpScore = 0.0
        freefallSampleCount = 0
        groundContactSampleCount = 0
        recentAccelerationData.removeAll(keepingCapacity: true)
        flightStartBarometricAltitude = currentBarometricAltitude
        maximumFlightBarometricAltitude = currentBarometricAltitude
    }
    
    /// Utilitário para clamp de valores
    private func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        max(minimum, min(maximum, value))
    }
}

// MARK: - Supporting Types

/// Direção de cruzamento de threshold
private enum CrossingDirection {
    case upward   // Cruzando para cima
    case downward // Cruzando para baixo
}

#else

// MARK: - Stub para outras plataformas

/// Stub do JumpDetector para compilação em outras plataformas (iOS, macOS)
import Combine

final class JumpDetector: ObservableObject {
    @Published var lastJumpHeight: Double = 0
    @Published var bestJumpHeight: Double = 0
    
    func start() {
        print("⚠️ JumpDetector só funciona no watchOS")
    }
    
    func stop() { }
    func setCustomFreefallThreshold(_ threshold: Double) { }
    func setCustomGroundThreshold(_ threshold: Double) { }
}

#endif

// MARK: - Notification Extensions

extension Notification.Name {
    /// Notificação enviada quando um salto é detectado
    static let jumpDetected = Notification.Name("jumpDetected")
}

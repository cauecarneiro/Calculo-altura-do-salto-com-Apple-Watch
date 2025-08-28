//
//  JumpDetector.swift
//  FutevoleiJumps
//

#if os(watchOS)

import Foundation
import CoreMotion
import Combine

final class JumpDetector: ObservableObject {
    // ========= Saídas p/ UI =========
    @Published var lastJumpHeight: Double = 0.0   // em metros
    @Published var bestJumpHeight: Double = 0.0
    @Published var jumpCount: Int = 0

    // ========= Core Motion =========
    private let motion = CMMotionManager()
    private let queue  = OperationQueue()

    // Altímetro (opcional)
    private let altimeter = CMAltimeter()
    private var baroAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    private var baroCurrent: Double = 0.0           // altitude relativa (m) desde start()
    private var baroFlightStart: Double = 0.0
    private var baroFlightMax: Double = 0.0

    // ========= Config =========
    private let gSI: Double = 9.80665               // m/s²
    private let updateHz: Double = 100.0            // 100 amostras/s

    // thresholds FUNCIONAIS
    private var freefallThreshold: Double = 0.40    // detecta queda facilmente
    private var groundThreshold:   Double = 1.15    // confirma chão

    // janelas/condições
    private let minFlightTime:     Double = 0.10
    private let maxFlightTime:     Double = 1.20    // aumentado para saltos altos

    private var needBelowFreefallSamples = 8        // confirmação sólida de queda livre
    private var needAboveGroundSamples   = 15       // confirmação muito rigorosa de pouso

    private var impactPeakG: Double = 2.5           // impacto obrigatório
    private var impactWindowSamples = 15            // janela normal
    
    // Parâmetros específicos para saltos altos
    private let highJumpThreshold: Double = 0.30    // threshold mais baixo para detecção
    private var velocityResetThreshold: Double = 0.5 // limiar para reset de velocidade em saltos altos
    
    // Sistema BÁSICO
    private var jumpScore: Double = 0.0             // pontuação do salto
    private let minJumpScore: Double = 4.0          // pontuação baixa = funciona
    
    // Histórico de velocidades para validação
    private var velocityHistory: [Double] = []
    private let velocityHistoryCap = 10

    // Filtro (EMA) — baixa latência
    private var ema: Double = 1.0
    private var rawA: Double = 1.0                  // valor sem filtro para detecção rápida
    private let alpha: Double = 0.30                // volta para valor mais conservador
    private let alphaFast: Double = 0.45            // filtro menos agressivo

    // ========= Estado interno =========
    private var inFlight = false
    private var tTakeoff: TimeInterval?
    private var tLandingCandidate: TimeInterval?    // cruzamento inicial do ground
    private var tApex: TimeInterval?
    private var apexFound = false

    // integração de velocidade vertical (para achar ápice)
    private var vVert: Double = 0.0                 // m/s

    // amostras recentes para checar pico de impacto
    private var recentG: [Double] = []
    private let recentCap = 64

    // contadores de estabilidade
    private var belowFreefallCount = 0
    private var aboveGroundCount   = 0

    // amostras anterior/atual (para interpolação)
    private var prevA: Double = 1.0
    private var prevT: TimeInterval = 0
    private var currA: Double = 1.0
    private var currT: TimeInterval = 0
    private var firstSample = true

    // baseline (para thresholds adaptativos suaves)
    private var baseMean: Double = 1.0
    private var baseM2: Double = 0.0
    private var baseCount: Int = 0
    private var useAdaptiveThresholds = true

    // Validação de padrão completo de salto
    private var preJumpStableCount = 0              // amostras estáveis antes do salto
    private let needPreJumpStable = 3               // apenas 30ms de estabilidade
    private var totalGVariation: Double = 0.0       // variação total durante o "salto"
    private var minGDuringFlight: Double = 1.0      // menor G durante voo
    private var maxGDuringLanding: Double = 0.0     // maior G durante pouso
    private var recentGHistory: [Double] = []       // histórico para detectar movimento de braço
    private let recentGHistoryCap = 20              // últimas 20 amostras

    // ========= API pública =========
    func start() {
        guard motion.isDeviceMotionAvailable else { return }

        resetSessionState()

        motion.deviceMotionUpdateInterval = 1.0 / updateHz
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] dm, _ in
            guard let self, let dm = dm else { return }
            self.handle(deviceMotion: dm)
        }

        if baroAvailable {
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue()) { [weak self] data, _ in
                guard let self, let d = data else { return }
                self.baroCurrent = d.relativeAltitude.doubleValue // metros
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        if baroAvailable { altimeter.stopRelativeAltitudeUpdates() }
    }

    // Ajuste de thresholds via UI desativa adaptação automática
    func setFreefallThreshold(_ threshold: Double) { freefallThreshold = threshold; useAdaptiveThresholds = false }
    func setGroundThreshold(_ threshold: Double)   { groundThreshold   = threshold; useAdaptiveThresholds = false }

    // ========= Núcleo =========
    private func handle(deviceMotion dm: CMDeviceMotion) {
        // 1) componente vertical (down-positivo) em "g"
        let aVert = verticalG(dm)

        // 2) filtro EMA duplo (normal + rápido)
        if firstSample {
            ema = aVert
            rawA = aVert
            prevA = aVert; prevT = dm.timestamp
            currA = aVert; currT = dm.timestamp
            firstSample = false
            return
        }
        
        // Filtro normal para estabilidade
        ema = alpha * aVert + (1 - alpha) * ema
        // Valor menos filtrado para detecção rápida
        rawA = alphaFast * aVert + (1 - alphaFast) * rawA

        // pares prev/curr para interpolação
        prevA = currA; prevT = currT
        currA = ema;   currT = dm.timestamp

        // ring de impacto
        recentG.append(currA)
        if recentG.count > recentCap { recentG.removeFirst() }
        
        // histórico para detecção de movimento de braço
        recentGHistory.append(currA)
        if recentGHistory.count > recentGHistoryCap { recentGHistory.removeFirst() }

        // baseline adaptativo (em apoio, sem saltos)
        updateBaselineIfGroundLike(a: currA)

        if !inFlight {
            // Validação PERMISSIVA de estabilidade
            if currA > 0.70 && currA < 1.30 {  // range muito amplo
                preJumpStableCount += 1
            } else {
                preJumpStableCount = max(0, preJumpStableCount - 1)  // decay suave
            }
            
            // Detecção FLEXÍVEL - permite continuar
            if preJumpStableCount >= needPreJumpStable || belowFreefallCount > 0 {
                // queda-livre - usa apenas valor filtrado para maior estabilidade
                if currA < freefallThreshold {
                    belowFreefallCount += 1
                    if belowFreefallCount == 1 {
                        tTakeoff = crossingTime(prevT: prevT, currT: currT, prevA: prevA, currA: currA, threshold: freefallThreshold)
                        vVert = 0
                        apexFound = false
                        tApex = nil
                        baroFlightStart = baroCurrent
                        baroFlightMax = baroCurrent
                        // Inicia monitoramento do padrão
                        totalGVariation = 0.0
                        minGDuringFlight = currA
                        maxGDuringLanding = 0.0
                        jumpScore = 0.0
                        #if DEBUG
                        print(String(format: "[TAKEOFF] g=%.2f  stable=%d  threshold=%.2f  STARTED", currA, preJumpStableCount, freefallThreshold))
                        #endif
                    }
                    
                    #if DEBUG
                    if belowFreefallCount > 1 && belowFreefallCount <= 3 {
                        print(String(format: "[FREEFALL] g=%.2f  count=%d/%d", currA, belowFreefallCount, needBelowFreefallSamples))
                    }
                    #endif
                } else {
                    belowFreefallCount = 0
                    tTakeoff = nil
                }
            } else {
                // Não permite detecção se não esteve estável
                belowFreefallCount = 0
                tTakeoff = nil
                #if DEBUG
                if currA < freefallThreshold && preJumpStableCount < needPreJumpStable {
                    print(String(format: "[BLOCKED] g=%.2f < %.2f mas stable=%d < %d", currA, freefallThreshold, preJumpStableCount, needPreJumpStable))
                }
                #endif
            }

            if belowFreefallCount >= needBelowFreefallSamples, tTakeoff != nil {
                inFlight = true
                aboveGroundCount = 0
                tLandingCandidate = nil
                recentG.removeAll(keepingCapacity: true)
                #if DEBUG
                print(String(format: "[IN_FLIGHT] g=%.2f  AIRBORNE", currA))
                #endif
            }
        } else {
            // Monitoramento do padrão durante o voo
            totalGVariation += abs(currA - prevA)
            minGDuringFlight = min(minGDuringFlight, currA)
            if currA > groundThreshold {
                maxGDuringLanding = max(maxGDuringLanding, currA)
            }
            
            // integração de velocidade (a - 1g) - volta para valor filtrado
            let dt = currT - prevT
            vVert += (currA - 1.0) * gSI * dt
            
            // Histórico de velocidades para validação
            velocityHistory.append(vVert)
            if velocityHistory.count > velocityHistoryCap {
                velocityHistory.removeFirst()
            }
            
            // Limita deriva mais conservadoramente
            if abs(vVert) > 6.0 {
                vVert = vVert > 0 ? 6.0 : -6.0
            }

            // ápice: detecção balanceada
            if !apexFound {
                let vPrev = vVert - (currA - 1.0) * gSI * dt
                // Detecção de ápice balanceada
                let crossedZero = vPrev < -0.1 && vVert >= -0.05  // menos restritivo
                let timeInFlight = currT - (tTakeoff ?? currT)
                let reasonableTime = timeInFlight > 0.10 && timeInFlight < 0.8  // janela mais ampla
                
                if crossedZero && reasonableTime {
                    let frac = abs(vVert) / (abs(vVert) + abs(vPrev) + 0.001)
                    let tZero = currT - max(0.0, min(1.0, frac)) * dt
                    tApex = tZero
                    apexFound = true
                }
            }

            // chão (acima do ground) + primeira borda interpolada
            if currA > groundThreshold {
                aboveGroundCount += 1
                if aboveGroundCount == 1 {
                    tLandingCandidate = crossingTime(prevT: prevT, currT: currT, prevA: prevA, currA: currA, threshold: groundThreshold)
                }
            } else {
                aboveGroundCount = 0
                tLandingCandidate = nil
            }

            // barômetro (pico durante o voo)
            if baroAvailable, baroCurrent > baroFlightMax {
                baroFlightMax = baroCurrent
            }

            // aterrissagem confirmada
            if aboveGroundCount >= needAboveGroundSamples,
               let t0 = tTakeoff,
               let tLand = tLandingCandidate {

                let hadImpact = recentG.suffix(impactWindowSamples).max() ?? 0.0
                let impactOk = hadImpact >= impactPeakG || apexFound
                
                // Sistema de pontuação inteligente
                jumpScore = calculateJumpScore(tFlight: tLand - t0, minG: minGDuringFlight, maxG: maxGDuringLanding, variation: totalGVariation, impact: hadImpact, apexFound: apexFound)
                let validJump = jumpScore >= minJumpScore

                if validJump {
                    var tFlight = tLand - t0
                    var useApexTime = false
                    
                    if let ta = tApex {
                        let tf = 2.0 * max(0.0, ta - t0) // corrige atraso do pouso
                        if tf > 0 {
                            // Use tempo do ápice apenas se razoável
                            if tf < tFlight * 1.5 { // não deixa divergir muito
                                tFlight = tf
                                useApexTime = true
                            }
                        }
                    }

                    guard tFlight >= minFlightTime, tFlight <= maxFlightTime else {
                        resetFlightOnly()
                        return
                    }

                    let h_g = gSI * tFlight * tFlight / 8.0
                    
                    // CÁLCULO DIRETO DE ALTURA
                    var finalH_g = h_g  // Altura pela fórmula gt²/8
                    
                    // Ajusta pela realidade dos saltos
                    if finalH_g >= 0.35 {       // Saltos altos (35cm+)
                        finalH_g *= 0.85         // Ajuste para saltos altos
                    } else if finalH_g >= 0.15 { // Saltos médios (15-35cm)
                        finalH_g *= 0.95         // Pequeno ajuste
                    } else {                     // Saltos baixos (<15cm)
                        finalH_g *= 1.1          // Aumenta um pouco
                    }
                    
                    // Usa barômetro apenas como validação
                    if baroAvailable {
                        let h_baro = max(0.0, baroFlightMax - baroFlightStart)
                        if h_baro > 0.08 && h_baro < 1.0 && abs(h_baro - finalH_g) < 0.3 {
                            finalH_g = 0.8 * finalH_g + 0.2 * h_baro  // Pequena correção
                        }
                    }
                    
                    let h = finalH_g

                    DispatchQueue.main.async {
                        self.lastJumpHeight = h
                        self.bestJumpHeight = max(self.bestJumpHeight, h)
                        self.jumpCount += 1
                        // >>> Notificação para a ContentView (modo calibração)
                        NotificationCenter.default.post(name: .jumpDetected, object: nil)
                        // WKInterfaceDevice.current().play(.success)
                    }

                    #if DEBUG
                    let jumpType = h >= 0.30 ? "HIGH" : h >= 0.20 ? "MED" : "LOW"
                    print(String(format: "[%@] t=%.3fs  score=%.1f  h=%.0fcm  minG=%.2f  peak=%.1fg",
                                 jumpType, tFlight, jumpScore, h*100, minGDuringFlight, hadImpact))
                    #endif

                    resetFlightOnly()
                } else {
                    let tFlightCheck = tLand - t0
                    #if DEBUG
                    print(String(format: "[REJECTED] t=%.3fs  score=%.1f < %.1f  impact=%.2fg  minG=%.2f  maxG=%.2f  var=%.1f",
                                 tFlightCheck, jumpScore, minJumpScore, hadImpact, minGDuringFlight, maxGDuringLanding, totalGVariation))
                    #endif
                    resetFlightOnly()
                }
            }
        }
    }

    // ========= Utilidades =========

    /// Projeta a aceleração total (user+gravity) no eixo "down" do mundo ⇒ valor em g.
    private func verticalG(_ dm: CMDeviceMotion) -> Double {
        let gx = dm.gravity.x, gy = dm.gravity.y, gz = dm.gravity.z
        let glen = max(1e-9, sqrt(gx*gx + gy*gy + gz*gz))
        let dx = gx / glen, dy = gy / glen, dz = gz / glen

        let ax = dm.userAcceleration.x + gx
        let ay = dm.userAcceleration.y + gy
        let az = dm.userAcceleration.z + gz

        return ax*dx + ay*dy + az*dz
    }

    /// Interpola o instante de cruzamento com um limiar entre duas amostras.
    private func crossingTime(prevT: Double, currT: Double, prevA: Double, currA: Double, threshold: Double) -> Double {
        let denom = (currA - prevA)
        if abs(denom) < 1e-9 { return currT }
        let frac = (threshold - prevA) / denom
        let clamped = max(0.0, min(1.0, frac))
        return prevT + clamped * (currT - prevT)
    }

    /// Atualiza baseline de "apoio" para thresholds adaptativos suaves.
    private func updateBaselineIfGroundLike(a: Double) {
        guard !inFlight, useAdaptiveThresholds else { return }
        if a > 0.7, a < 1.3 {
            baseCount += 1
            let delta = a - baseMean
            baseMean += delta / Double(baseCount)
            baseM2 += delta * (a - baseMean)

            if baseCount > 30 {  // mais amostras antes de adaptar
                let variance = baseM2 / Double(baseCount - 1)
                let sigma = sqrt(max(variance, 1e-6))
                groundThreshold = clamp(baseMean + 0.02, 0.90, 1.10)  // mais conservador
                // Threshold mais conservador
                let adaptiveFF = baseMean - 3.5 * sigma
                freefallThreshold = clamp(adaptiveFF, 0.25, 0.45)  // range mais conservador
            }
        }
    }

    private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, x))
    }

    /// Sistema FUNCIONAL de validação (0-10 pontos)
    private func calculateJumpScore(tFlight: Double, minG: Double, maxG: Double, variation: Double, impact: Double, apexFound: Bool) -> Double {
        var score: Double = 0.0
        
        // 1. Tempo de voo (0-3 pontos) - LIBERAL
        if tFlight >= 0.12 { score += 3.0 }      // Qualquer salto > 120ms
        
        // 2. Queda livre (0-2 pontos) - LIBERAL
        if minG < 0.75 { score += 2.0 }          // Queda livre razoável
        
        // 3. Volta ao chão (0-2 pontos) - LIBERAL
        if maxG > 1.2 { score += 2.0 }           // Voltou ao chão
        
        // 4. Variação (0-2 pontos) - LIBERAL
        if variation > 0.8 { score += 2.0 }      // Movimento razoável
        
        // 5. Impacto (0-1 ponto) - OPCIONAL
        if impact >= impactPeakG { score += 1.0 }
        
        return score
    }

    private func resetSessionState() {
        inFlight = false
        tTakeoff = nil
        tLandingCandidate = nil
        tApex = nil
        apexFound = false
        vVert = 0
        recentG.removeAll(keepingCapacity: true)
        belowFreefallCount = 0
        aboveGroundCount = 0
        prevA = 1.0; currA = 1.0
        rawA = 1.0
        prevT = 0;   currT = 0
        firstSample = true
        preJumpStableCount = 0
        totalGVariation = 0.0
        minGDuringFlight = 1.0
        maxGDuringLanding = 0.0
        recentGHistory.removeAll(keepingCapacity: true)
        jumpScore = 0.0
        baseMean = 1.0; baseM2 = 0.0; baseCount = 0
        baroCurrent = 0.0
        baroFlightStart = 0.0
        baroFlightMax = 0.0
    }

    private func resetFlightOnly() {
        inFlight = false
        tTakeoff = nil
        tLandingCandidate = nil
        tApex = nil
        apexFound = false
        vVert = 0
        velocityHistory.removeAll(keepingCapacity: true)
        totalGVariation = 0.0
        minGDuringFlight = 1.0
        maxGDuringLanding = 0.0
        jumpScore = 0.0
        belowFreefallCount = 0
        aboveGroundCount = 0
        recentG.removeAll(keepingCapacity: true)
        baroFlightStart = baroCurrent
        baroFlightMax = baroCurrent
    }
}

#else

// Stub para compilar fora do watchOS (previews/macOS/iOS)
import Combine
final class JumpDetector: ObservableObject {
    @Published var lastJumpHeight: Double = 0
    @Published var bestJumpHeight: Double = 0
    @Published var jumpCount: Int = 0
    func start() {}
    func stop() {}
    func setFreefallThreshold(_ threshold: Double) {}
    func setGroundThreshold(_ threshold: Double) {}
}

#endif

// MARK: - Extensões
extension Notification.Name {
    static let jumpDetected = Notification.Name("jumpDetected")
}


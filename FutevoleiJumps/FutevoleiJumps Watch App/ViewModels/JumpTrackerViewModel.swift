//
//  JumpTrackerViewModel.swift
//  Jump Tracker Watch App
//
//  ViewModel para gerenciar o estado da UI e coordenar com o detector de saltos
//

import SwiftUI
import Combine

// MARK: - Jump Tracker ViewModel

/// ViewModel responsável por gerenciar o estado da interface e coordenar com o detector de saltos
@MainActor
final class JumpTrackerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Dados atuais dos saltos para exibição na UI
    @Published private(set) var jumpData = JumpData()
    
    /// Estado de atividade do detector
    @Published private(set) var isActive = false
    
    /// Indica se houve erro na inicialização
    @Published var hasError = false
    
    /// Mensagem de erro, se houver
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    
    /// Instância do detector de saltos
    private let jumpDetector = JumpDetector()
    
    /// Set para gerenciar assinaturas do Combine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Inicia o sistema de detecção de saltos
    func startDetection() {
        do {
            jumpDetector.start()
            isActive = true
            hasError = false
            errorMessage = ""
        } catch {
            handleError(error)
        }
    }
    
    /// Para o sistema de detecção de saltos
    func stopDetection() {
        jumpDetector.stop()
        isActive = false
    }
    
    /// Reseta todos os dados de saltos
    func resetData() {
        jumpData = JumpData()
    }
    
    // MARK: - Private Methods
    
    /// Configura os bindings com o detector de saltos
    private func setupBindings() {
        // Observa mudanças na altura do último salto
        jumpDetector.$lastJumpHeight
            .combineLatest(jumpDetector.$bestJumpHeight)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lastHeight, bestHeight in
                self?.updateJumpData(lastHeight: lastHeight, bestHeight: bestHeight)
            }
            .store(in: &cancellables)
        
        // Observa notificações de saltos detectados
        NotificationCenter.default.publisher(for: .jumpDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleJumpDetected()
            }
            .store(in: &cancellables)
    }
    
    /// Atualiza os dados do salto
    private func updateJumpData(lastHeight: Double, bestHeight: Double) {
        jumpData = JumpData(
            lastHeight: lastHeight,
            bestHeight: bestHeight,
            timestamp: Date(),
            qualityScore: 0.0, // Será implementado se necessário
            flightTime: 0.0    // Será implementado se necessário
        )
    }
    
    /// Trata salto detectado
    private func handleJumpDetected() {
        // Aqui podem ser adicionadas ações adicionais quando um salto é detectado
        // Por exemplo: haptic feedback, sons, animações, etc.
    }
    
    /// Trata erros do sistema
    private func handleError(_ error: Error) {
        hasError = true
        errorMessage = error.localizedDescription
        isActive = false
    }
}

// MARK: - Computed Properties

extension JumpTrackerViewModel {
    /// Altura do último salto formatada para exibição
    var lastJumpFormatted: String {
        String(format: "Último: %.0f cm", jumpData.lastHeightCM)
    }
    
    /// Altura do melhor salto formatada para exibição
    var bestJumpFormatted: String {
        String(format: "Melhor: %.0f cm", jumpData.bestHeightCM)
    }
    
    /// Indica se há dados válidos para exibir
    var hasValidData: Bool {
        jumpData.bestHeight > 0
    }
}

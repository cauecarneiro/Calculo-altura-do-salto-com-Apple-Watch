//
//  JumpData.swift
//  Jump Tracker Watch App
//
//  Modelos de dados para o sistema de detecção de saltos
//

import Foundation

// MARK: - Jump Data Model

/// Representa os dados de um salto detectado
struct JumpData {
    /// Altura do último salto em metros
    let lastHeight: Double
    
    /// Altura do melhor salto registrado em metros
    let bestHeight: Double
    
    /// Timestamp do último salto
    let timestamp: Date
    
    /// Score de qualidade do salto (0-10)
    let qualityScore: Double
    
    /// Tempo de voo em segundos
    let flightTime: Double
    
    /// Inicializador
    init(lastHeight: Double = 0.0, 
         bestHeight: Double = 0.0, 
         timestamp: Date = Date(),
         qualityScore: Double = 0.0,
         flightTime: Double = 0.0) {
        self.lastHeight = lastHeight
        self.bestHeight = bestHeight
        self.timestamp = timestamp
        self.qualityScore = qualityScore
        self.flightTime = flightTime
    }
}

// MARK: - Jump Data Extensions

extension JumpData {
    /// Altura do último salto em centímetros
    var lastHeightCM: Double {
        lastHeight * 100
    }
    
    /// Altura do melhor salto em centímetros
    var bestHeightCM: Double {
        bestHeight * 100
    }
    
    /// Verifica se é um salto válido
    var isValidJump: Bool {
        lastHeight > 0 && flightTime > 0
    }
}

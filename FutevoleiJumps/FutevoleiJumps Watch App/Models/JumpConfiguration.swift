//
//  JumpConfiguration.swift
//  Jump Tracker Watch App
//
//  Configurações para o sistema de detecção de saltos
//

import Foundation

// MARK: - Jump Detection Configuration

/// Configurações otimizadas para detecção de saltos
struct JumpConfiguration {
    
    // MARK: - Thresholds Principais
    
    /// Threshold para detecção de queda livre (em g)
    /// Valores menores = mais sensível à detecção de saltos
    let freefallThreshold: Double = 0.32
    
    /// Threshold para detecção de pouso (em g)
    /// Valores maiores = mais rigoroso para confirmar pouso
    let groundThreshold: Double = 1.25
    
    // MARK: - Parâmetros de Confirmação
    
    /// Número de amostras necessárias para confirmar queda livre
    let needBelowFreefallSamples: Int = 5
    
    /// Número de amostras necessárias para confirmar pouso
    let needAboveGroundSamples: Int = 10
    
    /// Número de amostras de estabilidade necessárias antes do salto
    let needPreJumpStableSamples: Int = 4
    
    // MARK: - Parâmetros de Impacto
    
    /// Threshold mínimo para detecção de impacto (em g)
    let impactPeakG: Double = 2.2
    
    /// Janela de amostras para detectar pico de impacto
    let impactWindowSamples: Int = 20
    
    // MARK: - Sistema de Validação
    
    /// Score mínimo para considerar um salto válido (0-10)
    let minJumpScore: Double = 4.5
    
    /// Tempo mínimo de voo para considerar salto válido (segundos)
    let minFlightTime: Double = 0.10
    
    /// Tempo máximo de voo para considerar salto válido (segundos)
    let maxFlightTime: Double = 1.20
    
    // MARK: - Filtros de Sinal
    
    /// Coeficiente alpha para filtro EMA principal (suavização)
    let alphaFilter: Double = 0.25
    
    /// Coeficiente alpha para filtro EMA rápido (responsividade)
    let alphaFastFilter: Double = 0.40
    
    // MARK: - Parâmetros de Estabilidade
    
    /// Valor mínimo de aceleração para considerar estável (em g)
    let stableMinG: Double = 0.85
    
    /// Valor máximo de aceleração para considerar estável (em g)
    let stableMaxG: Double = 1.20
    
    // MARK: - Configurações de Hardware
    
    /// Frequência de atualização do acelerômetro (Hz)
    let updateFrequency: Double = 100.0
    
    /// Aceleração da gravidade padrão (m/s²)
    let standardGravity: Double = 9.80665
}

// MARK: - Configuration Extensions

extension JumpConfiguration {
    /// Configuração padrão otimizada
    static let `default` = JumpConfiguration()
    
    /// Configuração para saltos mais sensíveis
    static let sensitive = JumpConfiguration()
    
    /// Configuração para saltos mais rigorosos
    static let strict = JumpConfiguration()
}

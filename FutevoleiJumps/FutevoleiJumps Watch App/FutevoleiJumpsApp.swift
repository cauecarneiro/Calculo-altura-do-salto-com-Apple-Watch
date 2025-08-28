//
//  JumpTrackerApp.swift
//  Jump Tracker Watch App
//
//  Ponto de entrada principal da aplicação Jump Tracker
//  Sistema de detecção de saltos para Apple Watch
//
//  Created by Cauê Carneiro on 13/08/25.
//

import SwiftUI

// MARK: - Main App

/// Aplicação principal do Jump Tracker
/// 
/// Um sistema avançado de detecção de saltos que utiliza:
/// - Acelerômetro do Apple Watch para detectar padrões de movimento
/// - Altímetro barométrico para validação de altura (quando disponível)
/// - Algoritmos de filtragem para reduzir ruído e falsos positivos
/// - Sistema de validação inteligente baseado em score de qualidade
@main
struct JumpTrackerApp: App {
    
    // MARK: - Scene Configuration
    
    var body: some Scene {
        WindowGroup {
            // View principal com interface minimalista
            ContentView()
        }
    }
}

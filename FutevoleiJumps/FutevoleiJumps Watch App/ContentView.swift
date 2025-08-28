//
//  ContentView.swift
//  Jump Tracker Watch App
//
//  Interface principal para visualizar os dados de saltos detectados
//  Utiliza MVVM pattern para separação clara entre UI e lógica de negócio
//

import SwiftUI

// MARK: - Main Content View

/// View principal que exibe os dados de saltos de forma simples e direta
struct ContentView: View {
    
    // MARK: - Properties
    
    /// ViewModel responsável por gerenciar o estado e dados dos saltos
    @StateObject private var viewModel = JumpTrackerViewModel()
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Exibe a altura do último salto
            Text(viewModel.lastJumpFormatted)
                .font(.title3)
                .accessibilityLabel("Altura do último salto")
            
            // Exibe a altura do melhor salto
            Text(viewModel.bestJumpFormatted)
                .font(.title3)
                .accessibilityLabel("Altura do melhor salto registrado")
        }
        .onAppear {
            // Inicia a detecção quando a view aparece
            viewModel.startDetection()
        }
        .onDisappear {
            // Para a detecção quando a view desaparece
            viewModel.stopDetection()
        }
        .alert("Erro", isPresented: $viewModel.hasError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

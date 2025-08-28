//
//  ContentView.swift
//  FutevoleiJumps Watch App
//
//  Interface simples para visualizar os saltos detectados
//

import SwiftUI

struct ContentView: View {
    @StateObject private var detector = JumpDetector()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Futevôlei Jumps")
                    .font(.headline)
                    .foregroundColor(.orange)

                // Estatísticas principais
                VStack(spacing: 8) {
                    Text("Saltos: \(detector.jumpCount)")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(String(format: "Último: %.0f cm", detector.lastJumpHeight * 100))
                        .font(.title3)
                        .foregroundColor(.blue)

                    Text(String(format: "Melhor: %.0f cm", detector.bestJumpHeight * 100))
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                Divider()

                // Indicador de status
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Sistema Ativo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Instruções
                Text("Fique parado por um momento, depois salte!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            detector.start()
        }
        .onDisappear {
            detector.stop()
        }
    }
}



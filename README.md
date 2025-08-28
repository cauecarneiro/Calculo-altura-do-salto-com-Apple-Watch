# Calculo-altura-do-salto-com-Apple-Watch

Algoritmo em Swift para calcular a altura de saltos usando sensores do Apple Watch.  
Detecta o momento de saída do chão (takeoff) e o retorno (landing), medindo o tempo de voo para estimar a altura.

## Cálculo

A altura é estimada pela fórmula da cinemática:
h = (g * t²) / 8

- g = gravidade (9,81 m/s²)  
- t = tempo total de voo

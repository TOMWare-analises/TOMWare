# Especificação da Pintool Vazia (EmptyTool) e Protocolo de Probe da Condição PIN

Este documento estabelece os fundamentos técnicos para isolar a linha de base mínima do Intel Pin no projeto TOMWare.M, atendendo à Questão 2 do protocolo e à Seção 13 da especificação.

---

## 1. EmptyPinTool (Condição `EMPTY`)

### 1.1 Código-Fonte
O código-fonte está localizado em `EmptyPinTool/EmptyPinTool.cpp`:
```cpp
#include "pin.H"

int main(int argc, char* argv[])
{
    if (PIN_Init(argc, argv))
        return 1;
    PIN_StartProgram();
    return 0;
}
```

### 1.2 Características Técnicas
- **Nenhum hook de API ou biblioteca:** Não intercepta nenhuma chamada do sistema operacional ou da aplicação.
- **Nenhuma instrumentação JIT:** Não registra callbacks de TRACE, BBL ou INS.
- **Nenhuma manipulação de estruturas:** Não toca em PEB, TEB, heap ou tabelas de processos.
- **Nenhum log volumoso:** Não gera saída contínua em disco; apenas inicializa e transfere o controle.
- **Identificação do binário:**
  - Caminho relativo: `x64/Release/EmptyPinTool.dll`
  - SHA-256 do build: `804BE19BF7924B641FE25F07EA89DEC26DC9DAA36C49638F407FF96E2AB153C8`

### 1.3 Papel Científico
A `EmptyPinTool` não tem custo zero: ela inclui o carregamento da DLL da ferramenta no espaço de endereçamento do processo, a resolução de símbolos pelo Pin e o overhead do subsistema de injeção. Ela isola o custo estrito da infraestrutura TOMWare.M através do contraste:
$$\Delta_{TMW0} = \text{TMW0} - \text{EMPTY}$$

---

## 2. Probe da Condição `PIN` (Motor Pin sem Tool)

### 2.1 Hipótese Experimental
O Intel Pin é concebido como uma máquina de instrumentação dinâmica orientada a ferramentas (*tool-driven*). Em muitas configurações e versões do Pin no Windows, a invocação do executável sem a flag `-t <tool>` é rejeitada ou abortada pelo carregador.

### 2.2 Protocolo de Sondagem Automatizado
Antes de iniciar o plano de execuções de uma campanha:
1. O runner executa uma sondagem controlada:
   ```cmd
   pin.exe -- <target_benign_oracle>
   ```
2. O runner captura o código de retorno, stdout e stderr da tentativa.
3. **Critério de Validação:**
   - Se o processo executar e concluir com sucesso sem ferramenta, a condição `PIN` é marcada como `valid = true` no manifesto `campaign.json`, participando do plano completo (10 condições).
   - Se o Pin emitir mensagem de erro ou código de saída inválido indicando necessidade obrigatória de uma ferramenta, a condição `PIN` é marcada como `valid = false`.
4. **Decisão Científica Formal:**
   - Em caso de invalidade, `EMPTY` torna-se a baseline mínima comprovada de execução sob Pin.
   - A campanha opera com 9 condições ($100 \times 9 \times 10 = 9.000$ execuções no corpus principal).
   - O contraste `PIN - NAT` é registrado como `not_supported_by_engine` com a evidência do probe anexada ao relatório de auditoria, sem simular dados inexistentes.

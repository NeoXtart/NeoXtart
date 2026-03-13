# Progredindo no NeoXtart

Este guia e para te ajudar a continuar o projeto sem depender de uma explicacao longa toda vez.
O foco aqui e pratico: onde mexer, em que ordem mexer e como validar uma mudanca pequena.

## Mapa Mental do Fluxo

O caminho principal do interpretador hoje e:

`CLI -> source -> lexer -> parser -> runtime`

Em termos de arquivo:

- `cmd/neoxtart/main.v` recebe o comando da CLI.
- `source/source.v` resolve caminho e carrega o arquivo.
- `token/lexer/lexer.v` transforma texto em tokens.
- `parser/parser.v` transforma tokens em AST.
- `runtime/runtime.v` executa a AST.

## Pontas-chave do Projeto

### Por onde o script entra

Arquivo: `cmd/neoxtart/main.v`

O binario decide entre:

- `run`
- `check`
- `dump-tokens`
- `dump-ast`

Se voce quer adicionar um novo subcomando da CLI, comeca aqui.

### Como o arquivo vira texto

Arquivo: `source/source.v`

Responsabilidades:

- criar `Source`
- ler arquivo do disco
- resolver extensao e caminho do script
- montar diagnosticos com contexto de linha

Quando houver problema de caminho, extensao `.kix/.neo/.kx` ou mensagem de erro com arquivo/linha, olhe aqui.

### Como o texto vira token

Arquivos:

- `token/token.v`
- `token/lexer/lexer.v`

Aqui ficam:

- kinds de token
- regras do lexer
- tratamento de comentarios, strings, labels, `$var`, `@macro`, `%ENV%`

Se a linguagem precisa reconhecer uma palavra-chave nova, um simbolo novo ou um literal novo, quase sempre o primeiro passo esta aqui.

### Como o token vira AST

Arquivos:

- `ast/ast.v`
- `ast/dump.v`
- `parser/parser.v`

Aqui ficam:

- os nos da AST
- o dump textual da AST
- o parser de statements e expressoes

Regra pratica:

- sintaxe nova de statement: AST + parser
- sintaxe nova de expressao: AST + parser + precedencia, se necessario
- se o `dump-ast` ficar legivel, voce depura muito mais rapido

### Como a AST executa

Arquivo: `runtime/runtime.v`

Esse e o centro do interpretador hoje.
Aqui voce encontra:

- loop principal de execucao
- controle de `GOTO`, `GOSUB`, `RETURN`, `RESULT`, `EXIT`
- escopo global/local
- `DIM` e `GLOBAL`
- execucao de loops e condicionais

Se a sintaxe ja parseia mas ainda "nao faz nada", o proximo lugar quase sempre e este.

### Onde ficam builtins e expressoes

Arquivo: `runtime/builtins.v`

Aqui ficam:

- avaliacao de expressoes
- macros
- chamadas de builtin
- interpolacao de strings

Se voce quer adicionar uma funcao tipo `REVERSE(text)`, comece aqui.

### Onde fica tipagem

Arquivos:

- `runtime/types.v`
- `runtime/value.v`

Aqui ficam:

- tipos suportados (`i16`, `f64`, `bool`, `str`, `run`, etc.)
- coercoes
- valores padrao
- inferencia inicial de tipo
- representacao interna dos valores

Se uma atribuicao tipada falha ou um novo tipo precisa existir, olhe primeiro aqui.

### Onde ficam options e loader

Arquivos:

- `runtime/options.v`
- `runtime/loader.v`

`options.v` controla flags como:

- `Explicit`
- `CaseSensitivity`
- `NoVarsInStrings`
- `NoMacrosInStrings`
- `WrapAtEOL`

`loader.v` concentra:

- parse de arquivo
- `check_file`
- `dump_ast_file`
- `tokenize_file`

### Onde fica Windows-specific

Arquivo: `platform/windows/system.v`

Esse modulo deve guardar o que depende do Windows de forma isolada.
Se um comando precisa chamar algo especifico do sistema operacional, tente concentrar o detalhe aqui e manter o runtime mais limpo.

### Onde ficam diagnosticos

Arquivo: `source/diag/diag.v`

Quando voce precisar melhorar mensagem de erro, spans, exibicao de trecho da linha ou stack, este e o ponto certo.

## Onde Estao os Testes

A pasta canonica de testes agora e `tests/`.

Mapa rapido:

- `tests/lexer`: testes do lexer
- `tests/parser`: testes do parser
- `tests/runtime`: testes de execucao
- `tests/samples`: compatibilidade com samples maiores
- `tests/helpers`: helpers compartilhados
- `tests/fixtures/scripts`: scripts usados so em teste

Comando principal:

```powershell
v test tests
```

## Como Depurar uma Feature Nova

Use esta ordem:

1. tokenizar primeiro
2. inspecionar a AST depois
3. so entao adicionar comportamento no runtime
4. fechar com um teste de parser e um teste de runtime

Fluxo pratico:

1. Rode `dump-tokens` para ver se o lexer reconheceu a sintaxe.
2. Rode `dump-ast` para ver se o parser montou o no esperado.
3. So depois mexa em `runtime/runtime.v` ou `runtime/builtins.v`.
4. Termine com `v test tests`.

## Exemplo Pequeno: Adicionar um Builtin

Exemplo: `REVERSE(text)`

Arquivos para mexer:

- `runtime/builtins.v`
- `tests/runtime/runtime_test.v`

Passo minimo:

1. No `match` de `call_builtin`, adicione o caso `REVERSE`.
2. Valide a quantidade de argumentos com `require_arg_count`.
3. Implemente uma funcao pequena que receba o texto e devolva o reverso.
4. Adicione um teste de runtime chamando `REVERSE("abc")`.

O que esse exercicio te ensina:

- como builtin e resolvida
- como argumentos chegam no runtime
- como escrever um teste curto que protege a mudanca

## Exemplo Pequeno: Adicionar um Comando

Exemplo: `BEEP`

Arquivos para mexer:

- `ast/ast.v`
- `ast/dump.v`
- `parser/parser.v`
- `runtime/runtime.v`
- `platform/windows/system.v`
- `tests/parser/parser_test.v`
- `tests/runtime/runtime_test.v`

Passo minimo:

1. Crie um novo no de statement na AST, por exemplo `BeepStmt`.
2. Ensine o `dump-ast` a imprimir esse no.
3. No parser, reconheca `BEEP` como statement proprio.
4. No runtime, execute esse statement.
5. Se precisar tocar o sistema, crie uma funcao pequena em `platform/windows/system.v`.
6. Adicione um teste de parser e um teste de runtime.

O que esse exercicio te ensina:

- o caminho completo de uma feature
- como uma keyword sai do parser e chega no runtime
- como isolar um detalhe de plataforma fora do core

## Primeira Adicao Pequena Recomendada

Implemente `BEEP`.

Por que ela e boa para voce:

- mexe pouco no parser
- mexe pouco na AST
- mexe pouco no runtime
- toca integracao Windows sem te prender num problema grande
- e facil de validar
- tem risco baixo de quebrar compatibilidade

Contrato sugerido:

- sintaxe: `BEEP`
- sem argumentos
- vira statement proprio, nao raw command
- com `emit_console: false`, deve executar sem erro e sem produzir output
- com console habilitado, pode usar o caminho Windows ou um bell simples como fallback

Testes de aceitacao sugeridos:

- parser: `BEEP` vira um statement dedicado
- runtime: `run_text("BEEP", emit_console: false)` passa sem erro
- CLI: `neoxtart check` aceita script com `BEEP`

## Ordem Segura Para Evoluir o Projeto

Se voce for adicionar uma feature pequena, tente seguir sempre esta ordem:

1. escrever ou copiar um exemplo minimo do script
2. ver tokens
3. ver AST
4. implementar runtime
5. escrever testes
6. atualizar docs se a linguagem mudou

Essa ordem reduz retrabalho porque separa erro de lexer, erro de parser e erro de runtime.

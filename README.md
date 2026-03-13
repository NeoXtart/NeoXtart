# NeoXtart

NeoXtart e um interpretador inspirado em KiXtart, escrito em [V](https://vlang.io/).
O projeto ainda esta em fase inicial e prioriza tres coisas:

- codigo simples de ler e continuar;
- compatibilidade incremental com scripts KiXtart;
- erros explicitos `NX1001` para tudo o que ainda nao foi implementado.

O alvo principal neste momento e Windows.

## Estado atual

- CLI disponivel com `run`, `check`, `dump-tokens` e `dump-ast`.
- Sem dependencias externas declaradas em `v.mod`.
- Suite principal de testes em `tests/`.
- Exemplos pequenos e estaveis em `examples/v1/`.
- Amostras do KiXtart incluidas em `KiX4.70/` para comparacao e testes.
- Build e testes validados com `V 0.5.1 4c2ca95`.

Validacao feita nesta arvore em 2026-03-13:

```powershell
v version
v test tests
v -o .\neoxtart.exe .\cmd\neoxtart
.\neoxtart.exe check .\examples\v1\factorial.kix
```

## O Que Voce Precisa Para Compilar

Para compilar o projeto hoje, voce precisa de:

1. Windows 10, Windows 11 ou Windows Server.
2. Uma instalacao funcional do compilador V.
3. Um backend C funcional para o V no seu ambiente.
4. PowerShell ou outro shell no Windows.

Na pratica:

- O repositorio nao usa modulos V de terceiros.
- O repositorio nao usa `npm`, `cargo`, `pip`, `cmake` ou `make`.
- O repositorio nao exige banco de dados, servicos externos ou DLLs registradas para compilar.
- A pasta `KiX4.70/` ajuda em referencia e testes, mas nao e requisito de build.

Se o seu `v version` funciona e voce consegue compilar um programa simples em V no Windows, isso normalmente ja e suficiente para compilar o NeoXtart. Na instalacao padrao do V para Windows, esse backend costuma vir resolvido; se o seu setup for customizado, garanta que o backend C do V esteja operacional antes do build.

## Build Rapido

Clone o repositorio e gere o binario:

```powershell
git clone <seu-fork-ou-este-repo>
cd NeoXtart
v -o .\neoxtart.exe .\cmd\neoxtart
```

Isso gera `neoxtart.exe` na raiz do projeto.

Se voce quiser apenas executar sem gerar binario final:

```powershell
v run .\cmd\neoxtart run .\examples\v1\factorial.kix
```

## Uso Rapido

### Validar sintaxe

```powershell
v run .\cmd\neoxtart check .\examples\v1\factorial.kix
```

### Executar um script

```powershell
v run .\cmd\neoxtart run .\examples\v1\call_main.kix
```

### Inspecionar tokens

```powershell
v run .\cmd\neoxtart dump-tokens .\examples\v1\factorial.kix
```

### Inspecionar a AST

```powershell
v run .\cmd\neoxtart dump-ast .\examples\v1\result.kix
```

### Passar variaveis pela CLI

```powershell
v run .\cmd\neoxtart run .\script.kix --var '$Name=Neo'
```

### Usar o binario compilado

```powershell
.\neoxtart.exe run .\examples\v1\factorial.kix
.\neoxtart.exe check .\examples\v1\type_var.neo
```

## Exemplo Minimo

```vb
function Double($n)
    result $n * 2
endfunction

Double(21)
```

Veja exemplos prontos em:

- [`examples/v1/factorial.kix`](examples/v1/factorial.kix)
- [`examples/v1/result.kix`](examples/v1/result.kix)
- [`examples/v1/interpolation.kix`](examples/v1/interpolation.kix)
- [`examples/v1/type_var.kix`](examples/v1/type_var.kix)
- [`examples/v1/type_var.neo`](examples/v1/type_var.neo)

## O Que Ja Funciona Hoje

### CLI

- `run <script>`
- `check <script>`
- `dump-tokens <script>`
- `dump-ast <script>`

### Estrutura geral da linguagem

- lexer manual case-insensitive para keywords;
- comentarios de linha e bloco;
- labels;
- variaveis com `$Nome`;
- macros com `@MACRO`;
- variaveis de ambiente com `%PATH%`;
- strings com interpolacao de variaveis, macros e `%ENV%`;
- arrays literais e indexacao;
- chamadas de funcao;
- expressoes aritmeticas, logicas e de comparacao.

### Statements suportados

- atribuicao simples e atribuicao tipada;
- `DIM` e `GLOBAL`;
- `IF`, `ELSE IF`, `ELSE`, `ENDIF`;
- `SELECT` com casos;
- `WHILE`;
- `DO ... UNTIL`;
- `FOR`;
- `FOR EACH`;
- `GOTO`;
- `GOSUB`;
- `RETURN` para fluxo de `GOSUB`;
- `CALL` para executar outro script;
- `FUNCTION ... ENDFUNCTION`;
- `RESULT [valor]`;
- `EXIT [codigo]`;
- `SLEEP`;
- `CLS`;
- `AT`;
- `GET`.

### Tipagem suportada

NeoXtart suporta anotacoes estaticas opcionais:

- `i16`
- `f64`
- `bool`
- `str`
- `run`

Regras atuais:

- sem tipo explicito, o valor inicial define o tipo;
- `run` e o tipo dinamico de compatibilidade;
- declaracoes tipadas sem inicializador recebem um valor padrao;
- `typeof(...) is <tipo>` esta suportado.

### Extensoes em relacao ao KiXtart

- `RESULT [valor]` para retorno explicito de funcao;
- atribuicoes do estilo KiXtart para `$FunctionName` continuam validas;
- `RETURN` fica reservado ao fluxo de `GOSUB`;
- variaveis tipadas e parametros tipados;
- `typeof(...) is <tipo>` como forma preferida de checagem de tipo em `.neo`.

### Builtins implementadas

As builtins abaixo ja existem no runtime:

- `ABS`
- `ASC`
- `CHR`
- `CDBL`
- `CINT`
- `FIX`
- `INT`
- `CSTR`
- `VAL`
- `LEN`
- `LEFT`
- `RIGHT`
- `SUBSTR`
- `LTRIM`
- `RTRIM`
- `TRIM`
- `LCASE`
- `UCASE`
- `INSTR`
- `INSTRREV`
- `REPLACE`
- `IIF`
- `SPLIT`
- `JOIN`
- `UBOUND`
- `VARTYPE`
- `VARTYPENAME`
- `RND`
- `SRND`
- `EXIST`
- `DIR`
- `GETCOMMANDLINE`
- `ISDECLARED`
- `SETOPTION`
- `TYPEOF`

### Macros implementadas

- `@ERROR`
- `@SERROR`
- `@RESULT`
- `@DATE`
- `@TIME`
- `@MSECS`
- `@DAY`
- `@MDAYNO`
- `@WDAYNO`
- `@YDAYNO`
- `@MONTH`
- `@MONTHNO`
- `@YEAR`
- `@CURDIR`
- `@STARTDIR`
- `@SCRIPTDIR`
- `@SCRIPTNAME`
- `@SCRIPTEXE`
- `@KIX`
- `@PID`
- `@PRODUCTTYPE`
- `@INWIN`

### Opcoes de runtime implementadas via `SETOPTION`

- `Explicit`
- `CaseSensitivity`
- `NoVarsInStrings`
- `NoMacrosInStrings`
- `WrapAtEOL`

## Limitacoes Conhecidas

Estas limitacoes sao intencionais ou temporarias no estado atual:

- scripts tokenizados `.kx` ainda nao sao suportados;
- execucao real de membros e metodos de objetos ainda nao existe;
- comandos nao reconhecidos pelo subset atual falham com `NX1001`;
- funcoes/macros nao implementadas tambem falham com `NX1001`;
- `INCLUDE`, `RUN`, `SHELL`, `USE`, `PLAY` e outros comandos fora do subset atual ainda nao existem;
- COM, WMI, registry, printers, networking e macros dependentes de dominio/usuario ainda nao existem;
- `BIG`, `SMALL`, `COLOR` e `BOX` ja aparecem no parser/runtime, mas hoje ainda tem comportamento minimo;
- quando voce passa um script sem extensao, o resolver tenta `.kix` e `.kx`; para `.neo`, passe a extensao explicitamente.

## Estrutura do Repositorio

- `cmd/neoxtart`: CLI do projeto.
- `source`: leitura de script, resolucao de caminho e diagnosticos.
- `token/token.v`: kinds de token.
- `token/lexer`: lexer manual.
- `ast`: nos da AST e dump textual.
- `parser`: parser recursive descent.
- `runtime`: loader, opcoes, valores, builtins e execucao tree-walk.
- `platform/windows`: integracoes especificas de Windows.
- `examples/v1`: exemplos pequenos e estaveis.
- `tests`: testes de lexer, parser, runtime e samples.
- `docs/progredindo-no-neoxtart.md`: guia pratico para continuar o projeto.

## Testes

Para rodar toda a suite:

```powershell
v test tests
```

Arquivos principais de referencia:

- [`tests/README.md`](tests/README.md)
- [`docs/progredindo-no-neoxtart.md`](docs/progredindo-no-neoxtart.md)

## Fluxo de Desenvolvimento Recomendado

Quando adicionar uma feature nova, a ordem mais segura e:

1. verificar tokens;
2. verificar AST;
3. implementar runtime;
4. fechar com testes.

Comandos uteis:

```powershell
v run .\cmd\neoxtart dump-tokens .\caminho\script.kix
v run .\cmd\neoxtart dump-ast .\caminho\script.kix
v test tests
```

## Compatibilidade e Escopo

Este repositorio nao tenta fingir compatibilidade total com KiXtart ainda.
O objetivo da fase atual e ter um subset consistente, legivel e facil de expandir.
Tudo o que ainda nao existe deve falhar de forma explicita, em vez de ficar silenciosamente errado.

## Licenca

MIT.

# TS 7: How We Got There（Jake Bailey）

<https://2026.tskaigi.org/talks/37>

- TypeScriptはPythonより2倍以上使われている
- Performance woes
  - tsconfig.json
  - library complehention
  - new language features make ts slower
- Challenges
  - JavaScript wasn't designed for writing compilers
- Evaluating our options
  - A port. not a rewrite
  - Concurrency
  - Simple
- Why Go
  - Similat structure to TypeScriptはPythonより2倍以上使われている
  - Fast compile times
  - GC, ergonomic cyclic data structures
  - Concurrency without async / await
  - Easy to learn
- Testing Starategy
  - Snapshot testing
    - <https://vitest.dev/guide/snapshot>
  - Fuzzing
    - <https://go.dev/doc/security/fuzz/>
- TypeScript 6: The Bridge Release

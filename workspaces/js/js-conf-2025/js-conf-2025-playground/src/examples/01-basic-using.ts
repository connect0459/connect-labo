/**
 * 基本的な using 宣言のサンプル
 *
 * using宣言は、リソースの生存期間をレキシカルスコープに束縛し、
 * スコープ終了時に自動的にリソースを破棄します。
 */

/**
 * Disposableプロトコルを実装したリソースクラス
 *
 * Symbol.disposeメソッドを実装することで、
 * usingキーワードで管理できるようになります。
 */
export class ManagedResource {
  private isDisposed = false;

  constructor(private name: string) {}

  /**
   * リソースで行う処理
   */
  doWork(): void {
    if (this.isDisposed) {
      throw new Error(`Cannot use disposed resource`);
    }
    console.log(`[${this.name}] Working...`);
  }

  /**
   * Symbol.dispose メソッド - using宣言によって自動的に呼び出される
   *
   * スコープ終了時（正常終了、return、throw、break等）に必ず実行されます
   */
  [Symbol.dispose](): void {
    if (this.isDisposed) {
      return;
    }
    this.isDisposed = true;
    console.log(`[${this.name}] Resource disposed`);
  }
}

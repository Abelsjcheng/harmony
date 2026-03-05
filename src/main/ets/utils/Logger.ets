export class Logger {
  private static enabled: boolean = true;

  static enable(): void {
    this.enabled = true;
  }

  static disable(): void {
    this.enabled = false;
  }

  static info(tag: string, message: string): void {
    if (this.enabled) {
      console.info(`[${tag}] ${message}`);
    }
  }

  static debug(tag: string, message: string): void {
    if (this.enabled) {
      console.debug(`[${tag}] ${message}`);
    }
  }

  static warn(tag: string, message: string): void {
    if (this.enabled) {
      console.warn(`[${tag}] ${message}`);
    }
  }

  static error(tag: string, message: string): void {
    if (this.enabled) {
      console.error(`[${tag}] ${message}`);
    }
  }
}

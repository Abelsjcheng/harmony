export class Logger {
  private tag: string;
  private enabled: boolean = true;

  constructor(tag: string) {
    this.tag = tag;
  }

  info(message: string): void {
    if (this.enabled) {
      console.info(`[${this.tag}] ${message}`);
    }
  }

  warn(message: string): void {
    if (this.enabled) {
      console.warn(`[${this.tag}] ${message}`);
    }
  }

  error(message: string): void {
    if (this.enabled) {
      console.error(`[${this.tag}] ${message}`);
    }
  }

  debug(message: string): void {
    if (this.enabled) {
      console.debug(`[${this.tag}] ${message}`);
    }
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }
}

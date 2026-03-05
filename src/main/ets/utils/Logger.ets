import hilog from '@ohos.hilog';

export enum LogLevel {
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6,
  FATAL = 7
}

export interface LoggerConfig {
  enabled: boolean;
  level: LogLevel;
  domain: number;
  prefix: string;
}

const DEFAULT_CONFIG: LoggerConfig = {
  enabled: true,
  level: LogLevel.DEBUG,
  domain: 0xFF00,
  prefix: 'SkillSDK'
};

export class Logger {
  private static config: LoggerConfig = { ...DEFAULT_CONFIG };

  static configure(config: Partial<LoggerConfig>): void {
    Logger.config = { ...Logger.config, ...config };
  }

  static enable(): void {
    Logger.config.enabled = true;
  }

  static disable(): void {
    Logger.config.enabled = false;
  }

  static setLevel(level: LogLevel): void {
    Logger.config.level = level;
  }

  static debug(tag: string, message: string, ...args: Object[]): void {
    if (Logger.config.enabled && Logger.config.level <= LogLevel.DEBUG) {
      hilog.debug(Logger.config.domain, tag, message, args);
    }
  }

  static info(tag: string, message: string, ...args: Object[]): void {
    if (Logger.config.enabled && Logger.config.level <= LogLevel.INFO) {
      hilog.info(Logger.config.domain, tag, message, args);
    }
  }

  static warn(tag: string, message: string, ...args: Object[]): void {
    if (Logger.config.enabled && Logger.config.level <= LogLevel.WARN) {
      hilog.warn(Logger.config.domain, tag, message, args);
    }
  }

  static error(tag: string, message: string, ...args: Object[]): void {
    if (Logger.config.enabled && Logger.config.level <= LogLevel.ERROR) {
      hilog.error(Logger.config.domain, tag, message, args);
    }
  }

  static fatal(tag: string, message: string, ...args: Object[]): void {
    if (Logger.config.enabled && Logger.config.level <= LogLevel.FATAL) {
      hilog.fatal(Logger.config.domain, tag, message, args);
    }
  }

  static log(level: LogLevel, tag: string, message: string, ...args: Object[]): void {
    switch (level) {
      case LogLevel.DEBUG:
        Logger.debug(tag, message, ...args);
        break;
      case LogLevel.INFO:
        Logger.info(tag, message, ...args);
        break;
      case LogLevel.WARN:
        Logger.warn(tag, message, ...args);
        break;
      case LogLevel.ERROR:
        Logger.error(tag, message, ...args);
        break;
      case LogLevel.FATAL:
        Logger.fatal(tag, message, ...args);
        break;
    }
  }

  static formatMessage(tag: string, level: string, message: string): string {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level}] [${tag}] ${message}`;
  }

  static isEnabled(): boolean {
    return Logger.config.enabled;
  }

  static getLevel(): LogLevel {
    return Logger.config.level;
  }

  static getConfig(): LoggerConfig {
    return { ...Logger.config };
  }
}

export function createTag(module: string, component?: string): string {
  return component ? `${module}_${component}` : module;
}

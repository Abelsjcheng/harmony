import { SessionHistory, ChatMessage } from '../types';
import { Logger } from '../utils/Logger';
import dataPreferences from '@ohos.data.preferences';

export class StorageManager {
  private static instance: StorageManager;
  private storageKey: string;
  private logger: Logger;
  private prefs: any = null;
  private initPromise: Promise<void> | null = null;

  private constructor(storageKey: string) {
    this.storageKey = storageKey;
    this.logger = new Logger('StorageManager');
  }

  static getInstance(storageKey: string): StorageManager {
    if (!StorageManager.instance) {
      StorageManager.instance = new StorageManager(storageKey);
    }
    return StorageManager.instance;
  }

  private async initPrefs(): Promise<void> {
    if (this.prefs) {
      return;
    }

    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = new Promise(async (resolve, reject) => {
      try {
        const context = getContext();
        this.prefs = await dataPreferences.getPreferences(context, this.storageKey);
        this.logger.info('Preferences initialized');
        resolve();
      } catch (error) {
        this.logger.error(`Failed to initialize preferences: ${error}`);
        reject(error);
      }
    });

    return this.initPromise;
  }

  async saveSession(history: SessionHistory): Promise<void> {
    await this.initPrefs();

    try {
      const key = `session_${history.sessionId}`;
      await this.prefs.put(key, JSON.stringify(history));
      await this.prefs.flush();
      
      const indexKey = 'session_index';
      const indexData = await this.prefs.get(indexKey, '[]');
      const index: string[] = JSON.parse(indexData as string);
      
      if (!index.includes(history.sessionId)) {
        index.push(history.sessionId);
        await this.prefs.put(indexKey, JSON.stringify(index));
        await this.prefs.flush();
      }

      this.logger.info(`Session saved: ${history.sessionId}`);
    } catch (error) {
      this.logger.error(`Failed to save session: ${error}`);
      throw error;
    }
  }

  async getSession(sessionId: string): Promise<SessionHistory | null> {
    await this.initPrefs();

    try {
      const key = `session_${sessionId}`;
      const data = await this.prefs.get(key, null);
      
      if (!data) {
        return null;
      }

      return JSON.parse(data as string);
    } catch (error) {
      this.logger.error(`Failed to get session: ${error}`);
      return null;
    }
  }

  async getAllSessions(): Promise<SessionHistory[]> {
    await this.initPrefs();

    try {
      const indexKey = 'session_index';
      const indexData = await this.prefs.get(indexKey, '[]');
      const index: string[] = JSON.parse(indexData as string);

      const sessions: SessionHistory[] = [];
      for (const sessionId of index) {
        const session = await this.getSession(sessionId);
        if (session) {
          sessions.push(session);
        }
      }

      return sessions.sort((a, b) => b.updatedAt - a.updatedAt);
    } catch (error) {
      this.logger.error(`Failed to get all sessions: ${error}`);
      return [];
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    await this.initPrefs();

    try {
      const key = `session_${sessionId}`;
      await this.prefs.delete(key);

      const indexKey = 'session_index';
      const indexData = await this.prefs.get(indexKey, '[]');
      const index: string[] = JSON.parse(indexData as string);
      
      const newIndex = index.filter(id => id !== sessionId);
      await this.prefs.put(indexKey, JSON.stringify(newIndex));
      
      await this.prefs.flush();
      this.logger.info(`Session deleted: ${sessionId}`);
    } catch (error) {
      this.logger.error(`Failed to delete session: ${error}`);
      throw error;
    }
  }

  async clearAll(): Promise<void> {
    await this.initPrefs();

    try {
      const indexKey = 'session_index';
      const indexData = await this.prefs.get(indexKey, '[]');
      const index: string[] = JSON.parse(indexData as string);

      for (const sessionId of index) {
        const key = `session_${sessionId}`;
        await this.prefs.delete(key);
      }

      await this.prefs.delete(indexKey);
      await this.prefs.flush();
      this.logger.info('All sessions cleared');
    } catch (error) {
      this.logger.error(`Failed to clear all sessions: ${error}`);
      throw error;
    }
  }

  async saveMessage(sessionId: string, message: ChatMessage): Promise<void> {
    const session = await this.getSession(sessionId);
    
    if (session) {
      session.messages.push(message);
      session.updatedAt = Date.now();
      await this.saveSession(session);
    }
  }

  async getMessages(sessionId: string, limit?: number): Promise<ChatMessage[]> {
    const session = await this.getSession(sessionId);
    
    if (!session) {
      return [];
    }

    if (limit && limit > 0) {
      return session.messages.slice(-limit);
    }

    return session.messages;
  }
}

import preferences from '@ohos.data.preferences';
import { SkillMessage } from '../types/index';
import { Logger } from './Logger';

const TAG = 'PreferenceStorage';
const PREFERENCE_NAME = 'skill_session_data';
const MESSAGE_KEY_PREFIX = 'session_messages_';
const METADATA_KEY_PREFIX = 'session_metadata_';

export interface SessionMetadata {
  groupId: string;
  createdAt: number;
  updatedAt: number;
  messageCount: number;
}

export class PreferenceStorage {
  private static instance: PreferenceStorage | null = null;
  private preferences: preferences.Preferences | null = null;
  private isInitialized: boolean = false;

  private constructor() {}

  static getInstance(): PreferenceStorage {
    if (!PreferenceStorage.instance) {
      PreferenceStorage.instance = new PreferenceStorage();
    }
    return PreferenceStorage.instance;
  }

  async init(context: Object): Promise<void> {
    if (this.isInitialized && this.preferences) {
      return;
    }

    try {
      this.preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
      this.isInitialized = true;
      Logger.info(TAG, 'Preferences initialized');
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to initialize preferences: ${err.message}`);
      throw error;
    }
  }

  async saveMessages(groupId: string, messages: SkillMessage[]): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const key = `${MESSAGE_KEY_PREFIX}${groupId}`;
      const messagesJson = JSON.stringify(messages);
      await this.preferences.put(key, messagesJson);

      const metadataKey = `${METADATA_KEY_PREFIX}${groupId}`;
      const metadata: SessionMetadata = {
        groupId,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        messageCount: messages.length
      };
      await this.preferences.put(metadataKey, JSON.stringify(metadata));

      await this.preferences.flush();
      Logger.info(TAG, `Saved ${messages.length} messages for group ${groupId}`);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to save messages: ${err.message}`);
      throw error;
    }
  }

  async getMessages(groupId: string): Promise<SkillMessage[]> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const key = `${MESSAGE_KEY_PREFIX}${groupId}`;
      const messagesJson = await this.preferences.get(key, '') as string;

      if (!messagesJson) {
        return [];
      }

      const messages = JSON.parse(messagesJson) as SkillMessage[];
      Logger.info(TAG, `Loaded ${messages.length} messages for group ${groupId}`);
      return messages;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to get messages: ${err.message}`);
      return [];
    }
  }

  async clearMessages(groupId: string): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const key = `${MESSAGE_KEY_PREFIX}${groupId}`;
      await this.preferences.delete(key);

      const metadataKey = `${METADATA_KEY_PREFIX}${groupId}`;
      await this.preferences.delete(metadataKey);

      await this.preferences.flush();
      Logger.info(TAG, `Cleared messages for group ${groupId}`);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to clear messages: ${err.message}`);
      throw error;
    }
  }

  async getAllGroups(): Promise<string[]> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const keys = await this.preferences.getAllKeys();
      const groupIds = keys
        .filter(key => key.startsWith(MESSAGE_KEY_PREFIX))
        .map(key => key.replace(MESSAGE_KEY_PREFIX, ''));

      return groupIds;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to get all groups: ${err.message}`);
      return [];
    }
  }

  async getSessionMetadata(groupId: string): Promise<SessionMetadata | null> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const key = `${METADATA_KEY_PREFIX}${groupId}`;
      const metadataJson = await this.preferences.get(key, '') as string;

      if (!metadataJson) {
        return null;
      }

      return JSON.parse(metadataJson) as SessionMetadata;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to get session metadata: ${err.message}`);
      return null;
    }
  }

  async clearAllSessions(): Promise<void> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const keys = await this.preferences.getAllKeys();
      const sessionKeys = keys.filter(key =>
        key.startsWith(MESSAGE_KEY_PREFIX) || key.startsWith(METADATA_KEY_PREFIX)
      );

      for (const key of sessionKeys) {
        await this.preferences.delete(key);
      }

      await this.preferences.flush();
      Logger.info(TAG, `Cleared all sessions (${sessionKeys.length} keys)`);
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to clear all sessions: ${err.message}`);
      throw error;
    }
  }

  async getStorageSize(): Promise<number> {
    if (!this.preferences) {
      throw new Error('Preferences not initialized');
    }

    try {
      const keys = await this.preferences.getAllKeys();
      let totalSize = 0;

      for (const key of keys) {
        const value = await this.preferences.get(key, '');
        if (typeof value === 'string') {
          totalSize += value.length;
        }
      }

      return totalSize;
    } catch (error) {
      const err = error as Error;
      Logger.error(TAG, `Failed to get storage size: ${err.message}`);
      return 0;
    }
  }

  isStorageInitialized(): boolean {
    return this.isInitialized;
  }

  async close(): Promise<void> {
    if (this.preferences) {
      this.preferences = null;
      this.isInitialized = false;
      Logger.info(TAG, 'Preferences closed');
    }
  }
}

import preferences from '@ohos.data.preferences';
import { SkillMessage } from '../types/index';
import { Logger } from './Logger';

const TAG = 'PreferenceStorage';
const PREFERENCE_NAME = 'skill_session_data';
const MESSAGE_KEY_PREFIX = 'session_messages_';

export class PreferenceStorage {
  private static instance: PreferenceStorage | null = null;
  private preferences: preferences.Preferences | null = null;

  private constructor() {}

  static getInstance(): PreferenceStorage {
    if (!PreferenceStorage.instance) {
      PreferenceStorage.instance = new PreferenceStorage();
    }
    return PreferenceStorage.instance;
  }

  async init(context: any): Promise<void> {
    if (!this.preferences) {
      try {
        this.preferences = await preferences.getPreferences(context, PREFERENCE_NAME);
        Logger.info(TAG, 'Preferences initialized');
      } catch (error) {
        Logger.error(TAG, `Failed to initialize preferences: ${(error as Error).message}`);
        throw error;
      }
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
      await this.preferences.flush();
      Logger.info(TAG, `Saved ${messages.length} messages for group ${groupId}`);
    } catch (error) {
      Logger.error(TAG, `Failed to save messages: ${(error as Error).message}`);
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
      Logger.error(TAG, `Failed to get messages: ${(error as Error).message}`);
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
      await this.preferences.flush();
      Logger.info(TAG, `Cleared messages for group ${groupId}`);
    } catch (error) {
      Logger.error(TAG, `Failed to clear messages: ${(error as Error).message}`);
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
      Logger.error(TAG, `Failed to get all groups: ${(error as Error).message}`);
      return [];
    }
  }
}

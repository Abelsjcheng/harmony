import { SkillConfig, SkillMessage, SessionState, SkillResponse, MessageListener } from '../types/index';
import { SessionManager } from '../core/SessionManager';
import { describe, it, expect } from 'lib/mock_test';

describe('SessionManager', () => {
  let sessionManager: SessionManager | null = null;

  it('should initialize with config', () => {
    const config: SkillConfig = {
      groupId: 'test_group',
      userId: 'test_user',
      serverUrl: 'ws://localhost:8080/skill',
      enablePersistence: false
    };

    sessionManager = new SessionManager(config);
    expect(sessionManager).not.toBeNull();
  });

  it('should return idle state initially', () => {
    const config: SkillConfig = {
      groupId: 'test_group',
      serverUrl: 'ws://localhost:8080/skill'
    };

    sessionManager = new SessionManager(config);
    const state = sessionManager.getState();
    expect(state.status).toEqual('idle');
    expect(state.groupId).toEqual('test_group');
  });

  it('should create skill response with success', () => {
    const config: SkillConfig = {
      groupId: 'test_group',
      serverUrl: 'ws://localhost:8080/skill'
    };

    sessionManager = new SessionManager(config);
    const response = sessionManager.closeSkill();
    expect(response.success).toBe(true);
  });

  it('should handle empty message history', async () => {
    const config: SkillConfig = {
      groupId: 'test_group',
      serverUrl: 'ws://localhost:8080/skill'
    };

    sessionManager = new SessionManager(config);
    const messages = await sessionManager.getSessionMessage();
    expect(messages.length).toBe(0);
  });

  it('should return error when regenerating without instruction', async () => {
    const config: SkillConfig = {
      groupId: 'test_group',
      serverUrl: 'ws://localhost:8080/skill'
    };

    sessionManager = new SessionManager(config);
    const response = await sessionManager.regenerate();
    expect(response.success).toBe(false);
    expect(response.error?.code).toBe(-2);
  });
});

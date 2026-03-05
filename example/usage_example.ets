import { SkillSDK, createSkillSDK } from '@harmony/skill-sdk';
import type {
  MessageListener,
  SkillConfig,
  SessionState,
  SkillMessage,
  ConnectionState
} from '@harmony/skill-sdk';

async function example() {
  const sdk = createSkillSDK();

  const config: SkillConfig = {
    groupId: 'group_123',
    userId: 'user_456',
    serverUrl: 'ws://localhost:8080/skill',
    maxRetries: 3,
    timeout: 30000,
    enablePersistence: true,
    maxConnections: 5,
    reconnectInterval: 3000
  };

  const initResult = await sdk.initialize(config, getContext(this));
  if (!initResult.success) {
    console.error(`Initialize failed: ${initResult.error?.message}`);
    return;
  }

  const listener: MessageListener = {
    onMessage: (message: SkillMessage) => {
      console.info(`[${message.role}]: ${message.content}`);
    },
    onError: (error: Error) => {
      console.error(`Error: ${error.message}`);
    },
    onStateChange: (state: SessionState) => {
      console.info(`Session state: ${state.status}`);
    },
    onComplete: () => {
      console.info('Session completed');
    }
  };

  sdk.addMessageListener(listener);

  const connState: ConnectionState | null = sdk.getConnectionState();
  console.info(`Connections: ${connState?.connectionCount}/${connState?.maxConnections}`);
  console.info(`Available slots: ${connState?.availableSlots}`);

  const runResult = await sdk.runSkill('group_123', '帮我生成一个 HarmonyOS 应用');
  if (runResult.success) {
    console.info(`Session started: ${runResult.data?.sessionId}`);
  }

  const state: SessionState | null = sdk.getState();
  console.info(`Current status: ${state?.status}`);
  console.info(`Message count: ${state?.messageCount}`);

  const messages: SkillMessage[] = await sdk.getSessionMessage();
  console.info(`Total messages: ${messages.length}`);

  const sendResult = await sdk.send('请继续生成');
  console.info(`Send result: ${sendResult.success}`);

  const regenResult = await sdk.regenerate();
  console.info(`Regenerate result: ${regenResult.success}`);

  const stopResult = sdk.stopSkill({ force: false, reason: 'User requested' });
  console.info(`Stop result: ${stopResult.success}`);

  const closeResult = sdk.closeSkill();
  console.info(`Close result: ${closeResult.success}`);

  SkillSDK.reset();
}

async function multiTurnConversation() {
  const sdk = createSkillSDK();

  const config: SkillConfig = {
    groupId: 'group_multi',
    serverUrl: 'ws://localhost:8080/skill',
    enablePersistence: true
  };

  await sdk.initialize(config, getContext(this));

  sdk.addMessageListener({
    onMessage: (msg: SkillMessage) => {
      console.info(`[${msg.role}]: ${msg.content}`);
    },
    onStateChange: (state: SessionState) => {
      console.info(`State: ${state.status}`);
    }
  });

  await sdk.runSkill('group_multi', '什么是 HarmonyOS？');

  await new Promise(resolve => setTimeout(resolve, 2000));

  await sdk.send('它有什么特点？');

  await new Promise(resolve => setTimeout(resolve, 2000));

  await sdk.send('请举例说明');

  const history = await sdk.getSessionMessage();
  console.info(`Conversation history: ${history.length} messages`);

  sdk.closeSkill();
}

async function connectionManagement() {
  const sdk = createSkillSDK();

  const config: SkillConfig = {
    groupId: 'group_conn',
    serverUrl: 'ws://localhost:8080/skill',
    maxConnections: 3
  };

  await sdk.initialize(config, getContext(this));

  const connState = sdk.getConnectionState();
  if (connState) {
    console.info(`Max connections: ${connState.maxConnections}`);
    console.info(`Current connections: ${connState.connectionCount}`);
    console.info(`Available slots: ${connState.availableSlots}`);

    connState.connections.forEach(conn => {
      console.info(`Connection: ${conn.connectionId} - ${conn.status}`);
    });
  }

  if (sdk.isSessionActive()) {
    console.info('Session is active');
  }

  sdk.closeSkill();
}

export { example, multiTurnConversation, connectionManagement };

import SkillSDK from '@harmony/skill-sdk';
import { MessageListener } from '@harmony/skill-sdk';

async function example() {
  const sdk = SkillSDK.getInstance();
  
  const config = {
    groupId: 'group_123',
    userId: 'user_456',
    serverUrl: 'ws://localhost:8080/skill',
    maxRetries: 3,
    timeout: 30000,
    enablePersistence: true
  };
  
  await sdk.initialize(config, getContext(this));
  
  const listener: MessageListener = {
    onMessage: (message) => {
      console.info(`Received: ${message.content}`);
    },
    onError: (error) => {
      console.error(`Error: ${error.message}`);
    },
    onStateChange: (state) => {
      console.info(`State: ${state.status}`);
    }
  };
  
  sdk.addMessageListener(listener);
  
  await sdk.runSkill('group_123', '帮我生成一个 HarmonyOS 应用');
  
  const messages = await sdk.getSessionMessage();
  console.info(`Total messages: ${messages.length}`);
  
  await sdk.send('请继续');
  
  await sdk.regenerate();
  
  const state = sdk.getState();
  console.info(`Current status: ${state?.status}`);
  
  sdk.stopSkill();
  
  sdk.closeSkill();
}

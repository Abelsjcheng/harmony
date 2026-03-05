# Harmony Skill SDK

HarmonyOS ArkTS SDK for skill server interaction with IM clients, OpenCode skill server, and mini-programs.

## Features

- WebSocket-based real-time communication
- Session state management
- Local persistent storage using Preferences
- Multi-round conversation support
- Retry and reconnection mechanisms
- Error handling and logging

## Installation

```bash
ohpm install @harmony/skill-sdk
```

## Quick Start

```typescript
import SkillSDK from '@harmony/skill-sdk';
import { MessageListener } from '@harmony/skill-sdk';

const sdk = SkillSDK.getInstance();

await sdk.initialize({
  groupId: 'group_123',
  userId: 'user_456',
  serverUrl: 'ws://localhost:8080/skill',
  enablePersistence: true
}, getContext(this));

sdk.addMessageListener({
  onMessage: (message) => {
    console.info(message.content);
  },
  onStateChange: (state) => {
    console.info(state.status);
  }
});

await sdk.runSkill('group_123', 'Generate a HarmonyOS app');
```

## API Reference

### initialize(config, context)

Initialize the SDK with configuration.

### runSkill(groupId, instruction)

Start a skill execution session.

### closeSkill()

Close the WebSocket connection.

### stopSkill()

Stop skill callback without closing connection.

### regenerate()

Regenerate response based on current instruction.

### getSessionMessage()

Get all session messages from history.

### send(content)

Send user input to trigger continuous response.

### getState()

Get current session state.

### addMessageListener(listener)

Add message listener for real-time updates.

## License

Apache-2.0

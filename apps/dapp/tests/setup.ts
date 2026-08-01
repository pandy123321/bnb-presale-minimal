// ═══════════════════════════════════════════
// PANGU2 DApp — Test Setup
// ═══════════════════════════════════════════

import { config } from "@vue/test-utils";

// Stub Vue Transition/TransitionGroup to render immediately in tests
config.global.stubs = {
  transition: false,
  "transition-group": false,
  Teleport: false,
};

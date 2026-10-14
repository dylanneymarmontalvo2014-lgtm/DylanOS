// DYLANOS-MOCK: Review-only scenarios. They never query or modify the host system.
// DYLANOS-INTEGRATION: Replace scenario flags with Calamares module and system validation events.
export const mockErrorScenarios = [
  "language-error", "keyboard-invalid", "partition-no-disk", "partition-space", "partition-invalid", "partition-detection",
  "install-paused", "install-cancelled", "install-error", "reboot-required",
] as const;
export type MockErrorScenario = (typeof mockErrorScenarios)[number];

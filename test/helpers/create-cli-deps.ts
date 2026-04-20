import type { runCli } from '../../src/cli';

import { vi } from 'vitest';

export function createCliDeps(
  overrides: Partial<Parameters<typeof runCli>[1]> = {}
): Parameters<typeof runCli>[1] {
  return {
    argv: ['node', 'dist/cli/index.js'],
    platform: 'darwin',
    env: {},
    stdout: {
      write: vi.fn()
    } as unknown as NodeJS.WriteStream,
    stderr: {
      write: vi.fn()
    } as unknown as NodeJS.WriteStream,
    installerDirname: '/pkg/dist/cli',
    fs: {
      existsSync: vi.fn((file: string) => file === '/pkg/sqlboot'),
      chmodSync: vi.fn()
    },
    os: {
      platform: vi.fn(() => 'darwin')
    },
    spawnSync: vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null })),
    ...overrides
  };
}

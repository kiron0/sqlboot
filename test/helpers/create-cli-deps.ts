import type { runCli } from '../../src/cli';

import path from 'node:path';

import { vi } from 'vitest';

export const TEST_INSTALLER_DIRNAME = path.join(path.parse(process.cwd()).root, 'pkg', 'dist');
export const TEST_INSTALLER_PATH = path.join(path.parse(process.cwd()).root, 'pkg', 'sqlboot');
export const TEST_INSTALLER_FALLBACK_PATH = path.join(path.parse(process.cwd()).root, 'sqlboot');
export const TEST_WINDOWS_BOOTSTRAPPER_PATH = path.join(path.parse(process.cwd()).root, 'pkg', 'sqlboot-windows.ps1');
export const TEST_WINDOWS_BOOTSTRAPPER_FALLBACK_PATH = path.join(
  path.parse(process.cwd()).root,
  'sqlboot-windows.ps1'
);

export function createCliDeps(
  overrides: Partial<Parameters<typeof runCli>[1]> = {}
): Parameters<typeof runCli>[1] {
  return {
    argv: ['node', 'dist/index.js'],
    platform: 'darwin',
    env: {},
    stdout: {
      write: vi.fn()
    } as unknown as NodeJS.WriteStream,
    stderr: {
      write: vi.fn()
    } as unknown as NodeJS.WriteStream,
    installerDirname: TEST_INSTALLER_DIRNAME,
    fs: {
      existsSync: vi.fn((file: string) => file === TEST_INSTALLER_PATH),
      chmodSync: vi.fn()
    },
    os: {
      platform: vi.fn(() => 'darwin')
    },
    spawnSync: vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null })),
    ...overrides
  };
}

import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import {
  TEST_INSTALLER_FALLBACK_PATH,
  TEST_INSTALLER_PATH,
  TEST_WINDOWS_BOOTSTRAPPER_FALLBACK_PATH,
  TEST_WINDOWS_BOOTSTRAPPER_PATH,
  createCliDeps
} from '../helpers/create-cli-deps';

describe('runCli installer checks', () => {
  it('fails when bundled installer missing', () => {
    const deps = createCliDeps({
      fs: {
        existsSync: vi.fn(() => false),
        chmodSync: vi.fn()
      }
    });

    const status = runCli(['init'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith(
      `[ERROR] Bundled installer not found: ${TEST_INSTALLER_PATH} or ${TEST_INSTALLER_FALLBACK_PATH}\n`
    );
    expect(deps.fs.chmodSync).not.toHaveBeenCalled();
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('finds installer at package root when running from dist', () => {
    const existsSync = vi.fn((file: string) => file === TEST_INSTALLER_PATH);
    const deps = createCliDeps({
      fs: {
        existsSync,
        chmodSync: vi.fn()
      }
    });

    const status = runCli(['init'], deps);

    expect(status).toBe(0);
    expect(existsSync).toHaveBeenNthCalledWith(1, TEST_INSTALLER_PATH);
    expect(deps.fs.chmodSync).toHaveBeenCalledWith(TEST_INSTALLER_PATH, 0o755);
  });

  it('fails when chmod throws', () => {
    const deps = createCliDeps({
      fs: {
        existsSync: vi.fn(() => true),
        chmodSync: vi.fn(() => {
          throw new Error('nope');
        })
      }
    });

    const status = runCli(['init'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Unable to mark installer executable: nope\n');
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('fails on Windows when bundled bootstrapper missing', () => {
    const deps = createCliDeps({
      platform: 'win32',
      fs: {
        existsSync: vi.fn((file: string) => file === TEST_INSTALLER_PATH),
        chmodSync: vi.fn()
      }
    });

    const status = runCli(['init'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith(
      `[ERROR] Bundled Windows bootstrapper not found: ${TEST_WINDOWS_BOOTSTRAPPER_PATH} or ${TEST_WINDOWS_BOOTSTRAPPER_FALLBACK_PATH}\n`
    );
    expect(deps.fs.chmodSync).not.toHaveBeenCalled();
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });
});

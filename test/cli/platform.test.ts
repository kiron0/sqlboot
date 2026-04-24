import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import { TEST_INSTALLER_PATH, TEST_WINDOWS_BOOTSTRAPPER_PATH, createCliDeps } from '../helpers/create-cli-deps';

describe('runCli platform checks', () => {
  it('fails on unsupported platform', () => {
    const deps = createCliDeps({ platform: 'freebsd' as NodeJS.Platform });

    const status = runCli(['status'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith(
      '[ERROR] Unsupported platform: freebsd. sqlboot supports macOS, Linux, and Windows through WSL2 Ubuntu.\n'
    );
  });

  it('forwards Windows commands to PowerShell bootstrapper', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({
      platform: 'win32',
      fs: {
        existsSync: vi.fn((file: string) => file === TEST_INSTALLER_PATH || file === TEST_WINDOWS_BOOTSTRAPPER_PATH),
        chmodSync: vi.fn()
      },
      os: {
        platform: vi.fn(() => 'win32')
      },
      spawnSync: spawn
    });

    const status = runCli(['reset-pwd', 'new-secret'], deps);

    expect(status).toBe(0);
    expect(deps.fs.chmodSync).not.toHaveBeenCalled();
    expect(spawn).toHaveBeenCalledWith('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      TEST_WINDOWS_BOOTSTRAPPER_PATH,
      '-InstallerPath',
      TEST_INSTALLER_PATH,
      '-CommandName',
      'reset-pwd',
      '-CommandArgs',
      'new-secret'
    ], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('forwards Windows purge flag to PowerShell bootstrapper', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({
      platform: 'win32',
      fs: {
        existsSync: vi.fn((file: string) => file === TEST_INSTALLER_PATH || file === TEST_WINDOWS_BOOTSTRAPPER_PATH),
        chmodSync: vi.fn()
      },
      os: {
        platform: vi.fn(() => 'win32')
      },
      spawnSync: spawn
    });

    const status = runCli(['uninstall', '--purge'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      TEST_WINDOWS_BOOTSTRAPPER_PATH,
      '-InstallerPath',
      TEST_INSTALLER_PATH,
      '-CommandName',
      'uninstall',
      '-CommandArgs',
      '--purge'
    ], {
      stdio: 'inherit',
      env: {}
    });
  });
});

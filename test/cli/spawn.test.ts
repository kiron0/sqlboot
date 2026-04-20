import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import { createCliDeps } from '../helpers/create-cli-deps';

describe('runCli spawn', () => {
  it('spawns bundled installer with install flag', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['--flag'], deps);

    expect(status).toBe(0);
    expect(deps.fs.chmodSync).toHaveBeenCalledWith('/pkg/sqlboot', 0o755);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', '--install', '--flag'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('forwards explicit start mode without forcing install', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['--start'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', '--start'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('forwards explicit install mode without duplication', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['--install'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', '--install'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('maps init alias to install mode', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['init'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', '--install'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('maps start alias to start mode', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['start'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', '--start'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('forwards status subcommand', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['status'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', 'status'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('forwards reset-pwd subcommand with value', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['reset-pwd', 'new-secret'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', 'reset-pwd', 'new-secret'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('fails when spawn returns error', () => {
    const spawn = vi.fn(() => ({
      status: null,
      output: [],
      pid: 1,
      signal: null,
      stderr: null,
      stdout: null,
      error: new Error('spawn broke')
    }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['status'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] spawn broke\n');
  });

  it('forwards installer exit status', () => {
    const deps = createCliDeps({
      spawnSync: vi.fn(() => ({ status: 7, output: [], pid: 1, signal: null, stderr: null, stdout: null }))
    });

    const status = runCli(['status'], deps);

    expect(status).toBe(7);
  });
});

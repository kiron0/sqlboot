import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import { createCliDeps } from '../helpers/create-cli-deps';

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
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Bundled installer not found: /pkg/sqlboot or /sqlboot\n');
    expect(deps.fs.chmodSync).not.toHaveBeenCalled();
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('finds installer at package root when running from dist', () => {
    const existsSync = vi.fn((file: string) => file === '/pkg/sqlboot');
    const deps = createCliDeps({
      fs: {
        existsSync,
        chmodSync: vi.fn()
      }
    });

    const status = runCli(['init'], deps);

    expect(status).toBe(0);
    expect(existsSync).toHaveBeenNthCalledWith(1, '/pkg/sqlboot');
    expect(deps.fs.chmodSync).toHaveBeenCalledWith('/pkg/sqlboot', 0o755);
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
});

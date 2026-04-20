import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import { createCliDeps } from '../helpers/create-cli-deps';

describe('runCli uninstall', () => {
  it('forwards uninstall subcommand to bundled installer', () => {
    const spawn = vi.fn(() => ({ status: 0, output: [], pid: 1, signal: null, stderr: null, stdout: null }));
    const deps = createCliDeps({ spawnSync: spawn });

    const status = runCli(['uninstall'], deps);

    expect(status).toBe(0);
    expect(spawn).toHaveBeenCalledWith('bash', ['/pkg/sqlboot', 'uninstall'], {
      stdio: 'inherit',
      env: {}
    });
  });

  it('does not run uninstall when printing top-level help', () => {
    const deps = createCliDeps();

    const status = runCli([], deps);

    expect(status).toBe(0);
    expect(deps.stdout.write).toHaveBeenCalledWith(expect.stringContaining('uninstall'));
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });
});

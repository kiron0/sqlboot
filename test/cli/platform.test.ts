import { describe, expect, it, vi } from 'vitest';

import { runCli } from '../../src/cli';
import { createCliDeps } from '../helpers/create-cli-deps';

describe('runCli platform checks', () => {
  it('fails on unsupported platform', () => {
    const deps = createCliDeps({ platform: 'win32' });

    const status = runCli(['status'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith(
      '[ERROR] Unsupported platform: win32. sqlboot supports macOS and Linux.\n'
    );
  });

  it('fails when bash unavailable', () => {
    const deps = createCliDeps({
      os: {
        platform: vi.fn(() => 'win32')
      }
    });

    const status = runCli(['status'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] bash is required.\n');
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });
});

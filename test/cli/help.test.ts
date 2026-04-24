import { describe, expect, it } from 'vitest';

import { runCli } from '../../src/cli';
import { TEST_INSTALLER_PATH, createCliDeps } from '../helpers/create-cli-deps';

describe('runCli help', () => {
  it('prints help with no args', () => {
    const deps = createCliDeps();

    const status = runCli([], deps);

    expect(status).toBe(0);
    expect(deps.stdout.write).toHaveBeenCalledOnce();
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('forwards help subcommand to installer script', () => {
    const deps = createCliDeps();

    const status = runCli(['help'], deps);

    expect(status).toBe(0);
    expect(deps.spawnSync).toHaveBeenCalledWith('bash', [TEST_INSTALLER_PATH, 'help'], {
      stdio: 'inherit',
      env: {}
    });
  });
});

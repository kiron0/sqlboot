import { describe, expect, it } from 'vitest';

import { runCli } from '../../src/cli';
import { createCliDeps } from '../helpers/create-cli-deps';

describe('runCli command validation', () => {
  it('rejects unknown commands instead of defaulting to install', () => {
    const deps = createCliDeps();

    const status = runCli(['--flag'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Invalid command: --flag. Use "sqlboot help" for usage.\n');
    expect(deps.fs.chmodSync).not.toHaveBeenCalled();
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('rejects dashed options', () => {
    const deps = createCliDeps();

    const status = runCli(['--help'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Invalid command: --help. Use "sqlboot help" for usage.\n');
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('rejects removed install option', () => {
    const deps = createCliDeps();

    const status = runCli(['--install'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Invalid command: --install. Use "sqlboot help" for usage.\n');
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('rejects extra args for commands that do not take args', () => {
    const deps = createCliDeps();

    const status = runCli(['status', 'extra'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith(
      '[ERROR] Invalid command: status extra. Use "sqlboot help" for usage.\n'
    );
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });

  it('rejects reset-pwd without exactly one password value', () => {
    const deps = createCliDeps();

    const status = runCli(['reset-pwd'], deps);

    expect(status).toBe(1);
    expect(deps.stderr.write).toHaveBeenCalledWith('[ERROR] Invalid command: reset-pwd. Use "sqlboot help" for usage.\n');
    expect(deps.spawnSync).not.toHaveBeenCalled();
  });
});

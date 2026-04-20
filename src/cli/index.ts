#!/usr/bin/env node

'use strict';

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';

import { printHelp } from '../helpers/help';
import { ensureInstallerExecutable, getBash, resolveInstallerPath, supportedPlatforms } from '../helpers/installer';
import type { CliDeps } from '../types/cli';
import { logError } from '../utils/logger';

function getInstallerArgs(args: string[]): string[] {
  if (args[0] === '--help' || args[0] === '-h' || args[0] === 'help') {
    return ['help'];
  }

  if (args[0] === '--install' || args[0] === 'install' || args[0] === 'init') {
    return ['--install', ...args.slice(1)];
  }

  if (args[0] === '--start' || args[0] === 'start') {
    return ['--start', ...args.slice(1)];
  }

  if (['status', 'logs', 'doctor', 'reset-pwd', 'stop'].includes(args[0])) {
    return args;
  }

  return ['--install', ...args];
}

export function runCli(args: string[], deps: CliDeps): number {
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp(deps.stdout);
    return 0;
  }

  if (!supportedPlatforms.has(deps.platform)) {
    logError(`Unsupported platform: ${deps.platform}. sqlboot supports macOS and Linux.`, deps.stderr);
    return 1;
  }

  const installerPath = resolveInstallerPath(deps);
  if (!installerPath) {
    return 1;
  }

  if (!ensureInstallerExecutable(deps, installerPath)) {
    return 1;
  }

  const bash = getBash(deps.os.platform(), deps.stderr);
  if (!bash) {
    return 1;
  }

  const result = deps.spawnSync(bash, [installerPath, ...getInstallerArgs(args)], {
    stdio: 'inherit',
    env: deps.env
  });

  if (result.error) {
    logError(result.error.message, deps.stderr);
    return 1;
  }

  return result.status ?? 1;
}

const defaultDeps: CliDeps = {
  argv: process.argv,
  platform: process.platform,
  env: process.env,
  stdout: process.stdout,
  stderr: process.stderr,
  installerDirname: __dirname,
  fs,
  os,
  spawnSync
};

export function main(deps: CliDeps = defaultDeps): void {
  const status = runCli(deps.argv.slice(2), deps);
  if (status !== 0) {
    process.exit(status);
  }
}

if (require.main === module) {
  main();
}

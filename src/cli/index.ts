#!/usr/bin/env node

'use strict';

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';

import { printHelp } from '../helpers/help';
import {
  ensureInstallerExecutable,
  getBash,
  resolveInstallerPath,
  resolveWindowsBootstrapperPath,
  supportedPlatforms
} from '../helpers/installer';
import type { CliDeps } from '../types/cli';
import { logError } from '../utils/logger';

const NO_ARG_COMMANDS = new Set(['status', 'logs', 'doctor', 'stop', 'uninstall']);

function invalidCommand(args: string[], deps: CliDeps): null {
  logError(`Invalid command: ${args.join(' ')}. Use "sqlboot help" for usage.`, deps.stderr);
  return null;
}

function getInstallerArgs(args: string[], deps: CliDeps): string[] | null {
  if (args[0] === 'help' && args.length === 1) {
    return ['help'];
  }

  if (args[0] === 'init' && args.length === 1) {
    return ['init'];
  }

  if (args[0] === 'start' && args.length === 1) {
    return ['start'];
  }

  if (NO_ARG_COMMANDS.has(args[0]) && args.length === 1) {
    return args;
  }

  if (args[0] === 'uninstall' && args[1] === '--purge' && args.length === 2) {
    return args;
  }

  if (args[0] === 'reset-pwd' && args.length === 2) {
    return args;
  }

  return invalidCommand(args, deps);
}

export function runCli(args: string[], deps: CliDeps): number {
  if (args.length === 0) {
    printHelp(deps.stdout);
    return 0;
  }

  const installerArgs = getInstallerArgs(args, deps);
  if (!installerArgs) {
    return 1;
  }

  if (!supportedPlatforms.has(deps.platform)) {
    logError(`Unsupported platform: ${deps.platform}. sqlboot supports macOS, Linux, and Windows through WSL2 Ubuntu.`, deps.stderr);
    return 1;
  }

  const installerPath = resolveInstallerPath(deps);
  if (!installerPath) {
    return 1;
  }

  if (!ensureInstallerExecutable(deps, installerPath)) {
    return 1;
  }

  if (deps.platform === 'win32') {
    const windowsBootstrapperPath = resolveWindowsBootstrapperPath(deps);
    if (!windowsBootstrapperPath) {
      return 1;
    }

    const windowsArgs = [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      windowsBootstrapperPath,
      '-InstallerPath',
      installerPath,
      '-CommandName',
      installerArgs[0]
    ];

    if (installerArgs.length > 1) {
      windowsArgs.push('-CommandArgs', ...installerArgs.slice(1));
    }

    const result = deps.spawnSync('powershell.exe', windowsArgs, {
      stdio: 'inherit',
      env: deps.env
    });

    if (result.error) {
      logError(result.error.message, deps.stderr);
      return 1;
    }

    return result.status ?? 1;
  }

  const bash = getBash(deps.os.platform(), deps.stderr);
  if (!bash) {
    return 1;
  }

  const result = deps.spawnSync(bash, [installerPath, ...installerArgs], {
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

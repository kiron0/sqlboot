import path from 'node:path';

import { INSTALLER_EXECUTABLE_MODE, SUPPORTED_PLATFORMS } from '../constants/installer';
import type { CliDeps } from '../types/cli';
import { logError } from '../utils/logger';

export const supportedPlatforms = SUPPORTED_PLATFORMS;

export function resolveInstallerPath(deps: CliDeps): string | null {
  const candidates = [
    path.resolve(deps.installerDirname, '..', 'sqlboot'),
    path.resolve(deps.installerDirname, '..', '..', 'sqlboot')
  ];

  for (const candidate of candidates) {
    if (deps.fs.existsSync(candidate)) {
      return candidate;
    }
  }

  logError(`Bundled installer not found: ${candidates.join(' or ')}`, deps.stderr);
  return null;
}

export function ensureInstallerExecutable(deps: CliDeps, installerPath: string): boolean {
  try {
    deps.fs.chmodSync(installerPath, INSTALLER_EXECUTABLE_MODE);
    return true;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logError(`Unable to mark installer executable: ${message}`, deps.stderr);
    return false;
  }
}

export function getBash(osPlatform: NodeJS.Platform, stderr: NodeJS.WriteStream): string | null {
  if (osPlatform === 'win32') {
    logError('bash is required.', stderr);
    return null;
  }

  return 'bash';
}

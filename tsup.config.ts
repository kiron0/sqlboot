import { defineConfig } from 'tsup';

export default defineConfig([
  {
    entry: {
      'cli/index': './src/cli/index.ts'
    },
    format: ['cjs'],
    dts: false,
    clean: true,
    bundle: true,
    splitting: false,
    sourcemap: false,
    target: 'node16',
    minify: 'terser',
    outDir: 'dist'
  }
]);

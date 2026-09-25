import { defineConfig, globalIgnores } from 'eslint/config';
import nextVitals from 'eslint-config-next/core-web-vitals';

export default defineConfig([
  ...nextVitals,
  {
    rules: {
      // Pages load data with the useEffect(() => { load() }, []) pattern; keep
      // this React Compiler advisory visible without failing the lint run.
      'react-hooks/set-state-in-effect': 'warn',
    },
  },
  {
    // Node test files fake browser globals such as window.location directly.
    files: ['tests/**'],
    rules: {
      '@next/next/no-location-assign-relative-destination': 'off',
    },
  },
  globalIgnores(['.next/**', 'out/**', 'build/**', 'next-env.d.ts']),
]);

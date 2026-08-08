import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    watch: false,
    globals: true,
    environment: 'node',
    include: ['lua/nope/fixtures/vitest/*.test.ts'],
  },
})

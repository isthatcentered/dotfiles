import { describe, it, expect } from 'vitest'

describe('mixed suite', () => {
  it('passing test in mixed', () => {
    console.log('LOG: passing test in mixed executed')
    expect(true).toBe(true)
  })

  it('failing test in mixed', () => {
    console.log('LOG: failing test in mixed executed')
    expect(false).toBe(true)
  })
})

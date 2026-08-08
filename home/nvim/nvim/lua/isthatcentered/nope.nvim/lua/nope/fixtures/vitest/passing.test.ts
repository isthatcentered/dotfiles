import { describe, it, expect } from 'vitest'

describe('passing suite', () => {
  it('first passing test', () => {
    console.log('LOG: first passing test executed')
    expect(1 + 1).toBe(2)
  })

  it('second passing test', () => {
    console.log('LOG: second passing test executed')
    expect('hello').toBe('hello')
  })
})

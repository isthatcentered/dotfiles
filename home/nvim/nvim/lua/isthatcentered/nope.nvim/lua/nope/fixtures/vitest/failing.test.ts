import { describe, it, expect } from 'vitest'

describe('failing suite', () => {
  it('first failing test', () => {
    console.log('LOG: first failing test executed')
    expect(1 + 1).toBe(3)
  })

  it('second failing test', () => {
    console.log('LOG: second failing test executed')
    expect({ a: 1 }).toStrictEqual({ a: 2 })
  })
})

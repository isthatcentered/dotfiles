import { describe, it, expect } from 'vitest'

describe('Suite A', () => {
  it('passing test', () => {
    expect(true).toBe(true)
  })

  it('failing test', () => {
    expect({ hello: 'world' }).toStrictEqual({ hello: 'universe' })
  })
})

describe('Suite B', () => {
  it('another test', () => {
    expect(1 + 1).toBe(2)
  })
})

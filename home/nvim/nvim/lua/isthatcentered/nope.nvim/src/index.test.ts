import { describe, expect, it } from 'vitest'
import { greet } from './index'

describe('Suite A File A', () => {
  it('Passing test', () => {
    console.log('Passing test')

    expect(greet('World')).toBe('Hello, World!')
  })

  it('Failing test', () => {
    expect({ hello: 'world' }).toStrictEqual({ hello: 'not-world' })
  })
})

describe('Suite B File A', () => {
  it.skip(
    'Long running test',
    async () => {
      await new Promise(res => setTimeout(() => res(undefined), 1000 * 2000))
      console.log('Passing test')

      expect(greet('World')).toBe('Hello, World!')
    },
    1000 * 20
  )

  it('Failing test', () => {
    expect({ hello: 'world' }).toStrictEqual({ hello: 'not-world' })
  })

  it.skip('Timedout test', async () => {
    await new Promise(res => setTimeout(() => res(undefined), 1000 * 5))
  }, 1000)
})

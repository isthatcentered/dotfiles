import { describe, expect, it } from 'vitest'
import { greet } from './index'

describe('Suite B File B', () => {
  it('Passing test', () => {
    console.log('Passing test')


    expect(greet('World')).toBe('Hello, World!')
  })

  
})

describe('Suite C File B', () => {
  it(
    'Long running test',
    async () => {
      await new Promise(res => setTimeout(() => res(undefined), 1000 * 5))
      console.log('Passing test')

      expect(true).toBe(true)
    },
    1000 * 10
  )

  // it('Timedout test', async () => {
  //   await new Promise(res => setTimeout(() => res(undefined), 1000 * 5))
  // }, 1000)
})

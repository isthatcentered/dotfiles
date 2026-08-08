import { describe, expect, it } from 'vitest'
import { greet } from './index'

describe('Suite A File A', () => {
  it('Passing test', () => {
    console.log('Passing test')

    expect(greet('World')).toBe('Hello, World!')
  })

  
})



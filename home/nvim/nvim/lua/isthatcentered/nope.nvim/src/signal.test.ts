import { describe, expect, test } from 'vitest'
import { createEffect, createMemo, createSignal } from './signal'

describe('signal', () => {
  test('get/set', () => {
    const [value, setValue] = createSignal(0)

    expect(value()).toBe(0)

    setValue(1)

    expect(value()).toBe(1)
  })

    test('reactions', async () => {
      let reactedTimes = 0
      const [value, setValue] = createSignal(0)

      createEffect(() => {
        value()
        reactedTimes += 1
      })

      setValue(1)
      setValue(2)
      setValue(3)

      expect(reactedTimes).toBe(4)
    })

  describe('next', () => {
    test('derivation via reaction', () => {
      const changes: number[] = []
      const [valueA, setValueA] = createSignal(0)
      const [valueB, setValueB] = createSignal(0)

      createEffect(() => changes.push(valueA() + valueB()))

      setValueA(1)
      setValueB(2)
      setValueA(3)
      setValueB(3)

      expect(changes).toStrictEqual([0, 1, 3, 5, 6])
    })

    test('derivations', () => {
      const [valueA, setValueA] = createSignal(0)
      const [valueB, setValueB] = createSignal(0)

      const combinedValue = createMemo(() => valueA() + valueB())

      expect(combinedValue()).toStrictEqual(0)
      setValueA(1)
      expect(combinedValue()).toStrictEqual(1)
      setValueB(2)
      expect(combinedValue()).toStrictEqual(3)
      setValueA(3)
      expect(combinedValue()).toStrictEqual(5)
      setValueB(3)
      expect(combinedValue()).toStrictEqual(6)
    })
  })
})

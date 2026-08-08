/**
 * A simple utility function to demonstrate the TypeScript setup
 */
export function greet(name: string): string {
  if (!name.trim()) {
    throw new Error('Name cannot be empty')
  }
  return `Hello, ${name}!`
}

/**
 * A utility function to add two numbers
 */
export function add(a: number, b: number): number {
  return a + b
}

/**
 * A utility function to calculate the factorial of a number
 */
export function factorial(n: number): number {
  if (n < 0) {
    throw new Error('Factorial is not defined for negative numbers')
  }
  if (n === 0 || n === 1) {
    return 1
  }
  return n * factorial(n - 1)
}

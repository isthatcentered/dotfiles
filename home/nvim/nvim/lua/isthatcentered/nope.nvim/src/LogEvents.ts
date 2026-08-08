
// WeakSets to track method-level data logging overrides
const disableDataLogMethods = new WeakSet<Function>()
const enableDataLogMethods = new WeakSet<Function>()


// Configuration interface for the LogEvents decorator
export interface LogEventsConfig {
  enabled?: boolean // Enable/disable all logging (default: true)
  logEventName?: boolean // Enable/disable event name logging (default: true)
  logEventData?: boolean // Enable/disable event data logging (default: true)
  prefix?: string // Prefix for event name (default: '🛑')
}

// Class decorator that automatically logs method calls
export function LogEvents(config: LogEventsConfig = {}) {
  const {
    enabled = true,
    logEventName = true,
    logEventData = true,
    prefix = '🛑',
  } = config

  return function <T extends { new (...args: any[]): {} }>(constructor: T) {
    if (!enabled) return constructor

    // Get all method names from the prototype
    const methodNames = Object.getOwnPropertyNames(constructor.prototype)

    methodNames.forEach(methodName => {
      // Skip constructor
      if (methodName === 'constructor') return

      const originalMethod = constructor.prototype[methodName]

      // Only wrap functions
      if (typeof originalMethod !== 'function') return

      // Wrap the original method
      constructor.prototype[methodName] = function (...args: any[]) {
        // Log event name
        if (logEventName) {
          console.log(prefix, methodName)
        }

        // Determine if we should log event data for this specific method
        // Priority: method-level decorator > class-level config
        // If both decorators are present, @EnableEventDataLog wins
        let shouldLogData = logEventData

        // Check method-level overrides (enable has higher priority)
        if (enableDataLogMethods.has(originalMethod)) {
          shouldLogData = true // Force enable (highest priority)
        } else if (disableDataLogMethods.has(originalMethod)) {
          shouldLogData = false // Force disable
        }

        // Log event data based on final decision
        if (shouldLogData) {
          // Get parameter names from the original method
          const paramNames = getParameterNames(originalMethod)

          if (args.length === 1) {
            // Single argument - log directly
            console.log(args[0])
          } else if (args.length > 1 && paramNames.length > 0) {
            // Multiple arguments - create object with parameter names
            const argsObject: any = {}
            args.forEach((arg, index) => {
              const paramName = paramNames[index] || `arg${index}`
              argsObject[paramName] = arg
            })
            console.log(argsObject)
          }
        }

        // Call original method and return its result
        return originalMethod.apply(this, args)
      }
    })

    return constructor
  }
}

// Helper function to extract parameter names from a function
function getParameterNames(func: Function): string[] {
  const funcStr = func.toString()
  const match = funcStr.match(/\(([^)]*)\)/)
  if (!match || !match[1]) return []

  const params = match[1]
  return params
    .split(',')
    .map(param => param.trim().split(/[:\s=]/)[0])
    .filter((param): param is string => param !== undefined && param.length > 0)
}

/**
 * Method decorator to disable event data logging for a specific method.
 *
 * This decorator overrides the global `LogEvents({ logEventData: true })` setting
 * for the decorated method, preventing its arguments from being logged while still
 * logging the event name (if enabled).
 *
 * @example
 * ```typescript
 * @LogEvents({ logEventData: true })
 * class MyReporter implements Reporter {
 *   @DisableEventDataLog()
 *   onTestCaseReady(testCase: TestCase): Awaitable<void> {
 *     // Logs: 🛑 onTestCaseReady
 *     // Does NOT log testCase data
 *   }
 * }
 * ```
 *
 * @returns Method decorator function
 */
export function DisableEventDataLog() {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    // Mark this method to skip data logging
    disableDataLogMethods.add(descriptor.value)
    return descriptor
  }
}

/**
 * Method decorator to enable event data logging for a specific method.
 *
 * This decorator overrides the global `LogEvents({ logEventData: false })` setting
 * for the decorated method, forcing its arguments to be logged even when data
 * logging is globally disabled.
 *
 * If both `@EnableEventDataLog()` and `@DisableEventDataLog()` are applied to
 * the same method, `@EnableEventDataLog()` takes precedence.
 *
 * @example
 * ```typescript
 * @LogEvents({ logEventData: false })
 * class MyReporter implements Reporter {
 *   @EnableEventDataLog()
 *   onTestRunEnd(testModules, unhandledErrors, reason): Awaitable<void> {
 *     // Logs: 🛑 onTestRunEnd
 *     // Logs: {testModules, unhandledErrors, reason}
 *   }
 * }
 * ```
 *
 * @returns Method decorator function
 */
export function EnableEventDataLog() {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    // Mark this method to force data logging
    enableDataLogMethods.add(descriptor.value)
    return descriptor
  }
}


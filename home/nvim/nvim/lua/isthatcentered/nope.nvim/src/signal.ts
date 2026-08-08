// https://www.youtube.com/watch?v=vHy7GRpTpm8&list=LL&index=3&t=514s
// https://codesandbox.io/s/0xyqf?file=/reactive.js:0-1088

// A Dependency has many different Subscribers depending on it
// A particular Subscriber has many Dependencies
type Dependency = Set<Subscriber>
type Subscriber = {
  execute(): void
  dependencies: Set<Dependency>
}

type Signal<T> = [() => T, (value: T) => void]

const context: Subscriber[] = []

export function createSignal<T>(value: T): Signal<T> {
  const subscriptions: Dependency = new Set()

  const read = (): T => {
    const running = context[context.length - 1]
    console.log({ running, context })

    if (running) {
      subscriptions.add(running)

      running.dependencies.add(subscriptions) // you depend on this 
    }

    return value
  }

  const write = (nextValue: T) => {
    value = nextValue

    console.log({ subscriptions })
    for (const sub of [...subscriptions]) {
      sub.execute()
    }
  }

  return [read, write]
}

function cleanup(running: Subscriber) {
  for (const dep of running.dependencies) {
    dep.delete(running)
  }

  running.dependencies.clear()
}

export function createEffect(effect: () => void) {
  const execute = () => {
    for (const dep of running.dependencies) {
      dep.delete(running) // Remove this dep from all the subsribers 
    }
    running.dependencies.clear() // Remove all subscribers for this

    context.push(running)

    try {
      effect()
    } finally {
      context.pop()
    }
  }

  const running: Subscriber = {
    execute,
    dependencies: new Set(),
  }

  execute()
}

export function createMemo<T>(fn: () => T): () => T {
  const [read, write] = createSignal<T>(null as any)

  createEffect(() => write(fn()))

  return read
}

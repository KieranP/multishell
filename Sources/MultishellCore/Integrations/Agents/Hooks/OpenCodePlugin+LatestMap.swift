extension OpenCodePlugin {
  /// Ids and a value each, keeping only the latest, the service running for days;
  /// the oldest goes to `forget`, and one added again keeps a single place.
  static let latestMap = """
    const latestMap = (limit, forget = () => {}) => {
      const values = new Map()
      const add = (id, value) => {
        values.delete(id)
        values.set(id, value)
        if (values.size <= limit) return
        const oldest = values.keys().next().value
        values.delete(oldest)
        forget(oldest)
      }
      return {
        add,
        has: (id) => values.has(id),
        get: (id) => values.get(id),
        delete: (id) => values.delete(id),
        entries: () => [...values],
      }
    }

    """
}

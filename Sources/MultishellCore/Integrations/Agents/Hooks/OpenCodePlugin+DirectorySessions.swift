extension OpenCodePlugin {
  /// The placement records kept for each place, the service running for days.
  static let placementLimit = 1024

  /// Which sessions belong to the directory the plugin was loaded for.
  static let directorySessions = """
    // Hooks fire only for this directory's sessions, but the service's bus
    // carries every directory's and each loads the plugin; see agents.md.
    const directorySessions = ({ directory, get, track }) => {
      // How far each source's word on a session's place goes: a hook or a move is
      // this moment's, the newer winning; an envelope is the least. See agents.md.
      const rank = { envelope: 0, creation: 1, answer: 1, hook: 2, move: 2 }
      // Each session's place, the source that set it and when, its parent and agent,
      // bounded per place so other directories' sessions never push out this one's.
      const records = { here: latestMap(\(placementLimit)), elsewhere: latestMap(\(placementLimit)) }
      const recordOf = (id) => records.here.get(id) || records.elsewhere.get(id)
      const keep = (id, record) => {
        records[record.place === "here" ? "elsewhere" : "here"].delete(id)
        records[record.place].add(id, record)
      }
      const allRecords = () => [...records.here.entries(), ...records.elsewhere.entries()]
      const isHere = (info) => !!(info && info.location && info.location.directory === directory)
      const namesDirectory = (info) => !!(info && info.location && info.location.directory)
      const placeByLocation = (info) => (isHere(info) ? "here" : namesDirectory(info) ? "elsewhere" : undefined)
      const parentOf = (id) => {
        const record = recordOf(id)
        return (record && record.parentID) || track.parentOf(id)
      }
      const descendantsOf = (id) => allRecords().filter(([other]) => ancestorsOf(other, parentOf).includes(id))
      // A session the TUI moved away takes its whole line, though an answer filed the
      // one between.
      const isLineMovedAway = (parentID) =>
        [parentID, ...ancestorsOf(parentID, parentOf)].some((ancestor) => {
          const record = recordOf(ancestor)
          return !!record && record.source === "move" && record.place === "elsewhere"
        })
      // Where a creation or an answer puts a session: a child goes where its parent
      // is, and with a session the TUI moved away; anything else by its own location.
      const placeOf = (info) => {
        if (!info) return undefined
        const parent = info.parentID && recordOf(info.parentID)
        if (info.parentID && track.isWorker(info.parentID)) return "here"
        if (parent && parent.place === "here") return "here"
        if (info.parentID && isLineMovedAway(info.parentID)) return "elsewhere"
        return placeByLocation(info)
      }
      // A parent moved away after a session was placed takes it along, whatever
      // placed it, as its answer naming that parent may land after the move.
      const parentMovedAwaySince = (parentID, record) => {
        const parent = parentID && recordOf(parentID)
        return !!(parent && parent.source === "move" && parent.place === "elsewhere" && parent.at > record.at)
      }
      let clock = 0
      let arrivedHereAt = 0
      // A source's word, where nothing ranked above it has spoken, nor a move since
      // `saidAt`; a parent named by any source makes a session placed here a child.
      const file = (id, source, place, info, saidAt) => {
        const current = recordOf(id)
        const parentID = (info && info.parentID) || (current && current.parentID)
        const isKept = !!current && rank[current.source] > rank[source] && !parentMovedAwaySince(parentID, current)
        const isOutdated = saidAt !== undefined && parentMovedAwaySince(parentID, { at: saidAt })
        // A word naming no place leaves the record's place, source and time as they were.
        const hasSaid = !!place && !isKept && !isOutdated
        const where = hasSaid ? place : current && current.place
        if (!id || !where) return
        const agent = (info && info.agent) || (current && current.agent)
        keep(id, hasSaid ? { place: where, source, parentID, agent, at: ++clock } : { ...current, parentID, agent })
        if (where === "here" && parentID) track.onChild(id, parentID, agent)
        // A parent unknown here is asked about, so its own line, and a move of it, is known.
        if (where === "here" && parentID && !recordOf(parentID) && !track.isWorker(parentID)) lookUp(parentID)
        const relocates = hasSaid && changesPlace(id, current, source, where)
        if (relocates) relocate(id, where, source)
        // Any arrival here, and a move here whatever the record said, may bring a session
        // an envelope filed elsewhere, as an envelope names no parent.
        if (where === "here" && (relocates || source === "move")) arrivedHereAt = clock
      }
      // With no record, a move takes the sessions under it along; any other word does so
      // only when it files one that reported here elsewhere, as a first sight moves none.
      const changesPlace = (id, current, source, place) => {
        if (current) return current.place !== place
        return source === "move" || (place === "elsewhere" && track.hasReported(id))
      }
      // A session leaving or arriving takes every session under it along, on the word
      // that moved it, so a word that outranks that one can move them back.
      const relocate = (id, place, source) => {
        const descendants = descendantsOf(id)
        for (const [descendant, record] of descendants) {
          keep(descendant, { ...record, place, source, at: ++clock })
        }
        if (place !== "elsewhere") return
        track.onMovedAway(id, !!parentOf(id), descendants.map(([descendant]) => descendant))
      }
      // One lookup in flight per session. A task resumed by its id reuses its
      // session and announces nothing, so an answer naming a parent starts a child.
      const lookups = new Map()
      const lookUp = (id) => {
        if (!lookups.has(id)) {
          const answer = Promise.resolve()
            .then(() => get({ sessionID: id }))
            .then((info) => {
              if (info) file(id, "answer", placeOf(info), info)
              return info || null
            }, () => null)
            .finally(() => lookups.delete(id))
          lookups.set(id, answer)
        }
        return lookups.get(id)
      }
      const isPlacedHere = (id) => {
        const record = recordOf(id)
        return !!(record && record.place === "here")
      }
      // A child the roster forgot rejoins it from its record.
      const rejoinRoster = (id) => {
        const record = recordOf(id)
        if (record && record.parentID) track.onChild(id, record.parentID, record.agent)
      }
      // A session a hook names is here as of `firedAt`, so an event during its lookup is
      // read as its own; the answer, even after the bound, makes a child of it.
      const onNamed = async (id, firedAt) => {
        if (!id || track.isWorker(id)) return true
        const wasPlacedHere = isPlacedHere(id)
        file(id, "hook", "here", undefined, firedAt)
        if (!wasPlacedHere) await within(lookUp(id))
        return isPlacedHere(id) || track.isWorker(id)
      }
      // An envelope filed it and now names the other side, as after its parent's move.
      const envelopeDisagrees = (record, envelopeDirectory) => {
        if (record.source !== "envelope" || !envelopeDirectory) return false
        return (envelopeDirectory === directory) !== (record.place === "here")
      }
      // An envelope filed it elsewhere before its parent may have come back here.
      const isFiledBeforeAnArrival = (record) =>
        !!record && record.source === "envelope" && record.place === "elsewhere" && record.at < arrivedHereAt
      // An envelope naming this directory counts last, below the answer.
      const askWhere = async (id, envelopeDirectory) => {
        const info = await lookUp(id)
        if (envelopeDirectory) file(id, "envelope", envelopeDirectory === directory ? "here" : "elsewhere", info)
      }
      // An event's session, by its record, else an envelope naming another directory,
      // else an unbounded lookup, an envelope naming this one counting last.
      const locate = async (id, envelope) => {
        // A hook's lookup still out may yet make a child of it, so its answer comes
        // first, for a second: read before it, a child's end was the parent's Done.
        if (lookups.has(id)) await within(lookups.get(id))
        const record = recordOf(id)
        if (!record && track.isWorker(id)) return true
        const envelopeDirectory = envelope && envelope.directory
        if (isFiledBeforeAnArrival(record)) await askWhere(id, envelopeDirectory)
        else if (!record || envelopeDisagrees(record, envelopeDirectory)) {
          if (envelopeDirectory && envelopeDirectory !== directory) file(id, "envelope", "elsewhere")
          else await askWhere(id, envelopeDirectory)
        }
        if (!isPlacedHere(id)) return false
        rejoinRoster(id)
        return true
      }
      const onCreated = (data) => file(data.sessionID, "creation", placeOf(data), data)
      // The TUI moves a session to another worktree, which its new location says,
      // and every session under it goes with it.
      const onMoved = (data) => {
        const id = data.sessionID
        if (!id || track.isWorker(id)) return
        const place = placeByLocation(data)
        if (place) file(id, "move", place)
      }
      return { now: () => clock, onNamed, locate, onCreated, onMoved }
    }

    """
}

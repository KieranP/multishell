import Darwin

/// What this process's own footprint is made of, as far as the kernel and
/// malloc can say; see Docs/design/debug-tools.md for what each part takes in.
public struct ProcessMemoryParts: Sendable, Equatable {
  // VM_MEMORY_ANALYSIS_TOOL is left out: it tags MallocStackLogging's own pages.
  private static let mallocTags = Set(
    [
      VM_MEMORY_MALLOC, VM_MEMORY_MALLOC_SMALL, VM_MEMORY_MALLOC_LARGE, VM_MEMORY_MALLOC_HUGE,
      VM_MEMORY_SBRK, VM_MEMORY_REALLOC, VM_MEMORY_MALLOC_TINY, VM_MEMORY_MALLOC_LARGE_REUSABLE,
      VM_MEMORY_MALLOC_LARGE_REUSED, VM_MEMORY_MALLOC_NANO, VM_MEMORY_MALLOC_MEDIUM,
      VM_MEMORY_MALLOC_PROB_GUARD,
    ].map(UInt32.init)
  )
  private static let ioSurfaceTag = UInt32(VM_MEMORY_IOSURFACE)

  /// The kernel's graphics ledger and the IOSurfaces mapped in, Ghostty's
  /// render targets among them.
  public let gpuMemory: UInt64
  /// Every dirty or compressed page malloc holds, freed blocks included.
  public let heapMemory: UInt64
  /// What malloc has handed out and not had back.
  public let heapInUse: UInt64

  /// `nil` where the kernel will not describe the task.
  public static func ofThisProcess() -> Self? {
    guard let graphicsLedger = graphicsLedgerMemory() else { return nil }
    let dirtyByTag = dirtyMemoryByTag()
    var statistics = malloc_statistics_t()
    malloc_zone_statistics(nil, &statistics)
    return Self(
      gpuMemory: graphicsLedger + (dirtyByTag[ioSurfaceTag] ?? 0),
      heapMemory: dirtyByTag.filter { mallocTags.contains($0.key) }.values.reduce(0, +),
      heapInUse: UInt64(statistics.size_in_use),
    )
  }

  private static func graphicsLedgerMemory() -> UInt64? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { infoPointer in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), infoPointer, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return UInt64(info.ledger_tag_graphics_footprint)
      + UInt64(info.ledger_tag_graphics_footprint_compressed)
  }

  /// Submaps are stepped over, not entered: the shared library cache is one,
  /// thousands of regions holding a few MB, and entering it made the walk 15 times as long.
  private static func dirtyMemoryByTag() -> [UInt32: UInt64] {
    let pageSize = UInt64(getpagesize())
    var dirtyByTag: [UInt32: UInt64] = [:]
    var address: mach_vm_address_t = 0
    var size: mach_vm_size_t = 0
    var depth: natural_t = 0
    while true {
      var info = vm_region_submap_info_64()
      var count = mach_msg_type_number_t(
        MemoryLayout<vm_region_submap_info_64>.size / MemoryLayout<natural_t>.size
      )
      let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { infoPointer in
          mach_vm_region_recurse(mach_task_self_, &address, &size, &depth, infoPointer, &count)
        }
      }
      guard result == KERN_SUCCESS else { break }
      if info.is_submap == 0 {
        let pages = UInt64(info.pages_dirtied) + UInt64(info.pages_swapped_out)
        dirtyByTag[info.user_tag, default: 0] += pages * pageSize
      }
      address += size
    }
    return dirtyByTag
  }
}

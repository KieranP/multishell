import Foundation
import IOSurface
import Testing

@testable import MultishellProcess

@Suite
struct ProcessMemoryPartsTests {
  private static let blockSize = 256 << 20

  @Test func aTouchedHeapBlockCountsAsHeapInUseUntilFreed() throws {
    let before = try #require(ProcessMemoryParts.ofThisProcess())
    let block = try #require(malloc(Self.blockSize))
    memset(block, 1, Self.blockSize)
    let held = try #require(ProcessMemoryParts.ofThisProcess())
    free(block)
    let freed = try #require(ProcessMemoryParts.ofThisProcess())

    #expect(held.heapInUse >= before.heapInUse + UInt64(Self.blockSize / 2))
    #expect(held.heapMemory >= before.heapMemory + UInt64(Self.blockSize / 2))
    #expect(freed.heapInUse + UInt64(Self.blockSize / 2) <= held.heapInUse)
  }

  @Test func aDrawnIOSurfaceCountsAsGPUMemory() throws {
    let side = 4096
    let before = try #require(ProcessMemoryParts.ofThisProcess())
    let surface = try #require(
      IOSurface(properties: [
        .width: side, .height: side, .bytesPerElement: 4, .pixelFormat: 0x4247_5241,
      ])
    )
    surface.lock(options: [], seed: nil)
    memset(surface.baseAddress, 1, surface.allocationSize)
    surface.unlock(options: [], seed: nil)
    let after = try #require(ProcessMemoryParts.ofThisProcess())

    #expect(after.gpuMemory >= before.gpuMemory + UInt64(side * side * 4 / 2))
    withExtendedLifetime(surface) {}
  }
}

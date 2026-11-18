import Testing

@testable import MultishellProcess

@Suite
struct MemoryPressureLevelTests {
  @Test func theKernelsFlagsReadAsLevelsAndAnythingElseAsNone() {
    #expect(MemoryPressureLevel(kernelLevel: 1) == .normal)
    #expect(MemoryPressureLevel(kernelLevel: 2) == .warning)
    #expect(MemoryPressureLevel(kernelLevel: 4) == .critical)
    #expect(MemoryPressureLevel(kernelLevel: 3) == nil)
  }

  @Test func theSystemsLevelCanBeRead() {
    #expect(MemoryPressureLevel.current() != nil)
  }

  @Test func levelsOrderFromNormalToCritical() {
    #expect(MemoryPressureLevel.normal < .warning)
    #expect(MemoryPressureLevel.warning < .critical)
  }
}

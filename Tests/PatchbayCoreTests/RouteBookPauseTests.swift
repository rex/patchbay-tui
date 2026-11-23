import Testing

@testable import PatchbayCore

/// Pausing, rebuilding and the fast meter. None of these build a real route:
/// with no audio processes a wish only waits, which is all the logic here needs.
@Suite struct RouteBookPauseTests {
  private let headset = OutputDevice(
    id: 42, uid: "headset-uid", name: "Ear Force One", sampleRate: 48_000, isDefault: false)
  private let finder = AudioApp(key: "com.apple.finder", name: "Finder", processes: [])

  @Test @MainActor func pausingKeepsEveryWish() {
    let book = RouteBook()
    book.connect(finder.key, to: headset.uid)

    book.setPaused(true)

    #expect(book.isPaused)
    #expect(book.target(of: finder.key) == headset.uid)
    #expect(book.isWaiting(finder.key))
  }

  @Test @MainActor func aPausedBookStillLearnsNamesWhileItBuildsNothing() {
    let book = RouteBook()
    book.connect(finder.key, to: headset.uid)
    book.setPaused(true)

    let message = book.reconcile(apps: [finder], devices: [headset])

    #expect(message == nil)
    #expect(book.outputName(of: finder.key) == "Ear Force One")
    #expect(book.routedApps[finder.key] == "Finder")
    #expect(book.isWaiting(finder.key))
  }

  @Test @MainActor func resumingClearsThePause() {
    let book = RouteBook()
    book.setPaused(true)
    book.setPaused(false)
    #expect(!book.isPaused)
  }

  @Test @MainActor func rebuildingARouteThatIsNotLiveChangesNothing() {
    let book = RouteBook()
    book.connect(finder.key, to: headset.uid)

    book.rebuild(finder.key)

    #expect(book.target(of: finder.key) == headset.uid)
    #expect(book.meter(of: finder.key) == 0)
  }

  @Test func theMeterAndTheSilenceWatchReadSeparatePeaks() {
    let stats = RouteStats()
    stats.record(peak: 0.5, inputChannels: 2)

    #expect(stats.takeMeter() == 0.5)
    #expect(stats.takeMeter() == 0)  // reset by the read
    #expect(stats.take().peak == 0.5)  // the once-a-second reader still sees it

    stats.record(peak: 0.25, inputChannels: 2)
    #expect(stats.take().peak == 0.25)
    #expect(stats.takeMeter() == 0.25)
  }
}

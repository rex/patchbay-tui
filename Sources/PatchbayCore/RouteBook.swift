/// What the person asked for (this app → that output) versus what is running.
///
/// A wish lasts until the person disconnects it, and survives restarts through
/// `remember()` / `restore(_:)`. While its app has no audio processes (Finder
/// before a preview, Chrome not running) or its output is away (AirPods in their
/// case), it waits and the app plays normally; it goes live the moment both are
/// there. It is rebuilt whenever the app's processes change (a QuickLook preview
/// starting, a browser helper spawning). Volumes are kept per app.
@MainActor
public final class RouteBook {
  private var wishes: [String: String] = [:]
  private var routes: [String: Route] = [:]
  private var volumes: [String: Volume] = [:]
  private var levels: [String: Float] = [:]
  private var watches: [String: SilenceWatch] = [:]
  /// Last-seen names, so a waiting route can be shown and remembered by name.
  private var appNames: [String: String] = [:]
  private var outputNames: [String: String] = [:]

  public init() {}

  /// The output an app is routed to, live or waiting.
  public func target(of key: String) -> String? { wishes[key] }
  /// Routed, but nothing is playing through it right now.
  public func isWaiting(_ key: String) -> Bool { wishes[key] != nil && routes[key] == nil }
  public func level(of key: String) -> Float { levels[key] ?? 0 }
  /// The loudest sample on a live route since the last call. Poll it as often as
  /// a level display needs; `measure` and the silence watch are not disturbed.
  public func meter(of key: String) -> Float { routes[key]?.stats.takeMeter() ?? 0 }
  public func isSilent(_ key: String) -> Bool { watches[key]?.isSilent ?? false }
  /// While paused nothing is tapped: every wish waits, so every app is audible
  /// on its normal output. The way out when routes are silent and apps are muted.
  public private(set) var isPaused = false
  /// Every routed app, live or waiting, as key → name: these stay listed.
  public var routedApps: [String: String] {
    wishes.keys.reduce(into: [:]) { $0[$1] = appNames[$1] ?? $1 }
  }
  public func outputName(of key: String) -> String? { outputNames[key] }

  public func volume(for key: String) -> Volume {
    if let volume = volumes[key] { return volume }
    let volume = Volume()
    volumes[key] = volume
    return volume
  }

  public func connect(_ key: String, to uid: String) { wishes[key] = uid }

  public func disconnect(_ key: String) {
    wishes[key] = nil
    routes.removeValue(forKey: key)?.stop()
    levels[key] = nil
    watches[key] = nil
  }

  /// Makes the running routes match the wishes. Returns a message worth showing
  /// when an output goes away or a route can't be built.
  public func reconcile(apps: [AudioApp], devices: [OutputDevice]) -> String? {
    var message: String?
    for (key, uid) in wishes {
      if isPaused {
        // Keep the names fresh so waiting routes still read well; build nothing.
        if let app = apps.first(where: { $0.key == key }) { appNames[key] = app.name }
        if let device = devices.first(where: { $0.uid == uid }) { outputNames[key] = device.name }
        continue
      }
      let app = apps.first { $0.key == key }
      if let app { appNames[key] = app.name }
      let name = appNames[key] ?? key
      guard let device = devices.first(where: { $0.uid == uid }) else {
        if let route = routes.removeValue(forKey: key) {
          route.stop()
          message = "\(route.device.name) went away; \(name) plays normally until it's back"
        }
        continue
      }
      outputNames[key] = device.name
      guard let app else {
        routes.removeValue(forKey: key)?.stop()
        continue
      }
      let wanted = Set(app.processes.map(\.objectID))
      if let route = routes[key], route.device.uid == uid,
        Set(route.app.processes.map(\.objectID)) == wanted
      {
        continue
      }
      routes.removeValue(forKey: key)?.stop()
      watches[key] = nil
      guard !wanted.isEmpty else { continue }  // wait for the app to make a sound
      do {
        routes[key] = try Route(app: app, device: device, volume: volume(for: key))
      } catch {
        disconnect(key)
        message = "Couldn't route \(app.name): \(error)"
      }
    }
    return message
  }

  /// Once a second: reads each live route's meter, and returns the permission
  /// advice the first time a playing app's route turns out silent.
  public func measure(apps: [AudioApp], host: String?) -> String? {
    var advice: String?
    for (key, route) in routes {
      let peak = route.stats.take().peak
      levels[key] = peak
      let playing = apps.first { $0.key == key }?.isPlaying ?? false
      if watches[key, default: SilenceWatch()].observe(peak: peak, appIsPlaying: playing) {
        advice = SilenceWatch.advice(appName: route.app.name, host: host)
      }
    }
    return advice
  }

  /// Stops every route; each app goes back to its normal output.
  public func stopAll() {
    for route in routes.values { route.stop() }
    routes.removeAll()
  }

  /// Pausing stops every route at once and keeps every wish. Resuming lets the
  /// next `reconcile` build them again.
  public func setPaused(_ paused: Bool) {
    isPaused = paused
    guard paused else { return }
    stopAll()
    levels.removeAll()
    watches.removeAll()
  }

  /// Tears one live route down so the next `reconcile` builds it fresh, for a
  /// route that has gone quiet while others carry sound.
  public func rebuild(_ key: String) {
    routes.removeValue(forKey: key)?.stop()
    levels[key] = nil
    watches[key] = nil
  }

  /// Every wish, for saving: app, output, and the app's volume. Apps known only by
  /// process ID (`afplay`) are left out: the ID means nothing after they exit.
  public func remember() -> RouteMemory {
    RouteMemory(
      routes: wishes.keys.filter { !$0.hasPrefix("pid:") }.sorted().map { key in
        let volume = volume(for: key)
        return RouteMemory.Entry(
          app: key, appName: appNames[key] ?? key, output: wishes[key] ?? "",
          outputName: outputNames[key] ?? "", volume: volume.perMille / 10,
          muted: volume.isMuted)
      })
  }

  /// Adds saved wishes (call once, at startup). Nothing goes live until `reconcile`.
  public func restore(_ memory: RouteMemory) {
    for entry in memory.routes where !entry.app.isEmpty && !entry.output.isEmpty {
      wishes[entry.app] = entry.output
      appNames[entry.app] = entry.appName
      outputNames[entry.app] = entry.outputName
      let volume = volume(for: entry.app)
      volume.set(perMille: entry.volume * 10)
      volume.setMuted(entry.muted)
    }
  }
}

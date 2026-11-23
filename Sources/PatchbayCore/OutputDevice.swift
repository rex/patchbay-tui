import CoreAudio

/// A device that can play sound: speakers, headphones, AirPods, an interface.
public struct OutputDevice: Sendable, Hashable, Identifiable {
  public let id: AudioDeviceID
  /// Stable across reboots and reconnects; what a saved route should remember.
  public let uid: String
  public let name: String
  public let sampleRate: Double
  public let isDefault: Bool

  public init(id: AudioDeviceID, uid: String, name: String, sampleRate: Double, isDefault: Bool) {
    self.id = id
    self.uid = uid
    self.name = name
    self.sampleRate = sampleRate
    self.isDefault = isDefault
  }

  /// Every device with at least one output stream, default first, then by name.
  /// Aggregates are left out, including the private ones patchbay builds itself.
  public static func all() throws -> [OutputDevice] {
    let defaultID: AudioDeviceID = try HAL.value(
      HAL.system, kAudioHardwarePropertyDefaultOutputDevice, initial: 0)
    let ids = try HAL.objectIDs(HAL.system, kAudioHardwarePropertyDevices)
    let devices = ids.compactMap { id -> OutputDevice? in
      guard HAL.size(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput) > 0
      else { return nil }
      let transport: UInt32 =
        (try? HAL.value(id, kAudioDevicePropertyTransportType, initial: 0)) ?? 0
      guard transport != kAudioDeviceTransportTypeAggregate else { return nil }
      guard let uid = try? HAL.string(id, kAudioDevicePropertyDeviceUID) else { return nil }
      return OutputDevice(
        id: id,
        uid: uid,
        name: (try? HAL.string(id, kAudioObjectPropertyName)) ?? uid,
        sampleRate: (try? HAL.value(id, kAudioDevicePropertyNominalSampleRate, initial: 0.0))
          ?? 0,
        isDefault: id == defaultID)
    }
    return devices.sorted {
      $0.isDefault != $1.isDefault
        ? $0.isDefault : $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
  }

  /// Makes this the Mac's default output, exactly as choosing it in Sound
  /// settings would. Everything without a route follows it.
  public func makeDefault() throws {
    var address = HAL.address(kAudioHardwarePropertyDefaultOutputDevice)
    var device = id
    let status = AudioObjectSetPropertyData(
      HAL.system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &device)
    try HAL.check(status, "set the default output to \(name)")
  }

  /// Calls `handler` on `queue` whenever a device is connected or removed, or
  /// the default output changes. For the life of the process.
  public static func onListChange(queue: DispatchQueue, _ handler: @escaping @Sendable () -> Void) {
    for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
      var address = HAL.address(selector)
      AudioObjectAddPropertyListenerBlock(HAL.system, &address, queue) { _, _ in handler() }
    }
  }
}

import Foundation
#if os(macOS)
import CoreAudio
import AppKit
import Darwin
#endif

/// HAL resources are confined to this actor. The real-time block captures only integer addresses
/// and immutable scalars; parameter storage is allocated before IO and freed after IOProc destruction.
public actor CoreAudioRoutingBackend: AudioRouteBackend {
    #if os(macOS)
    private struct Route {
        var tap: AudioObjectID
        var device: AudioObjectID
        var io: AudioDeviceIOProcID?
        let gain: UnsafeMutablePointer<Int32>
        let fault: UnsafeMutablePointer<Int32>
        let meter: UnsafeMutablePointer<Int32>
    }
    private struct Listener {
        let object: AudioObjectID
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }
    private var routes: [String: Route] = [:]
    private var listeners: [Listener] = []
    private var handler: (@MainActor @Sendable (String?) -> Void)?
    private var healthTask: Task<Void, Never>?
    private var sleepObserver: (any NSObjectProtocol)?
    private enum NativeEvent: Sendable { case changed(Bool), sleeping }
    private var eventContinuation: AsyncStream<NativeEvent>.Continuation?
    private var eventTask: Task<Void, Never>?
    private var observedSources: [AudioApplicationSource] = []
    private var observedOutput: AudioObjectID = 0
    private let ownBundleID: String
    public init(ownBundleID: String = Bundle.main.bundleIdentifier ?? "com.zeuve.app") { self.ownBundleID = ownBundleID }

    public func discoverSources() async throws -> [AudioApplicationSource] {
        guard #available(macOS 14.2, *) else { throw QuickUtilityError.unavailable("El mezclador necesita macOS 14.2 o posterior.") }
        let processes = try objects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
        var records: [(object: UInt32, pid: Int32, bundle: String, input: Bool, output: Bool)] = []
        for object in processes {
            let pid: Int32 = try scalar(object, kAudioProcessPropertyPID, initial: 0)
            guard pid != ProcessInfo.processInfo.processIdentifier else { continue }
            guard let bundle = try string(object, kAudioProcessPropertyBundleID), !bundle.isEmpty else { continue }
            let input: UInt32 = try scalar(object, kAudioProcessPropertyIsRunningInput, initial: 0)
            let output: UInt32 = try scalar(object, kAudioProcessPropertyIsRunningOutput, initial: 0)
            records.append((object, pid, bundle, input != 0, output != 0))
        }
        let inputBundles = Set(records.filter { $0.input }.map { $0.bundle })
        var grouped: [String: (name: String, objects: [UInt32], excluded: String?)] = [:]
        for record in records where record.output {
            let reason = AudioRoutingPolicy.exclusionReason(bundleID: record.bundle, ownBundleID: ownBundleID, runningInput: inputBundles.contains(record.bundle))
            let name = NSRunningApplication(processIdentifier: pid_t(record.pid))?.localizedName ?? record.bundle
            var entry = grouped[record.bundle] ?? (name, [], nil)
            entry.objects.append(record.object); if let reason { entry.excluded = reason }; grouped[record.bundle] = entry
        }
        return grouped.map { key, entry in
            AudioApplicationSource(id: key, name: entry.name, processIDs: entry.objects.sorted(), supportsRouting: entry.excluded == nil, limitation: entry.excluded)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    public func startRoute(source: AudioApplicationSource, gain: Float) async throws {
        guard #available(macOS 14.2, *) else { throw QuickUtilityError.unavailable("El mezclador necesita macOS 14.2 o posterior.") }
        guard gain.isFinite, (0...1).contains(gain), source.supportsRouting, !source.processIDs.isEmpty else { throw QuickUtilityError.failure("Fuente o volumen no válido.") }
        if routes[source.id] != nil { try await setGain(sourceID: source.id, gain: gain); return }
        // Revalidate process identity and input usage immediately before intercepting audio.
        try Task.checkCancellation()
        let current = try await discoverSources()
        guard current.contains(where: { $0.id == source.id && $0.processIDs == source.processIDs && $0.supportsRouting }) else {
            throw QuickUtilityError.unavailable("La fuente ha cambiado; vuelve a seleccionarla.")
        }
        let output: AudioObjectID = try scalar(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, initial: 0)
        guard output != 0, let outputUID = try string(output, kAudioDevicePropertyDeviceUID) else { throw QuickUtilityError.unavailable("No hay una salida física disponible.") }
        // Never start an aggregate containing microphone streams. Combined duplex devices require
        // an explicitly verified stream-usage implementation and are not silently supported.
        guard try objects(output, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput).isEmpty else {
            throw QuickUtilityError.unavailable("Esta salida combina entrada y salida; no se captura para proteger el micrófono. Selecciona una salida independiente.")
        }
        let outputStreams = try objects(output, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        guard outputStreams.count == 1 else { throw QuickUtilityError.unavailable("Esta salida no ofrece una única ruta estéreo compatible.") }
        let outputFormat: AudioStreamBasicDescription = try scalar(outputStreams[0], kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
        guard Self.supported(outputFormat) else { throw QuickUtilityError.unavailable("La salida necesita PCM estéreo Float32; no se modifica su formato.") }
        let description = CATapDescription(stereoMixdownOfProcesses: source.processIDs)
        description.uuid = UUID(); description.name = "ZEUVE · ruta temporal"
        description.isPrivate = true; description.muteBehavior = .mutedWhenTapped
        var tap: AudioObjectID = 0
        try check(AudioHardwareCreateProcessTap(description, &tap))
        var aggregate: AudioObjectID = 0
        var io: AudioDeviceIOProcID?
        let parameter = UnsafeMutablePointer<Int32>.allocate(capacity: 3)
        parameter.initialize(repeating: Int32((gain * 1_000_000).rounded()), count: 3)
        parameter.advanced(by: 1).pointee = 1_000_000
        parameter.advanced(by: 2).pointee = 0
        let fault = UnsafeMutablePointer<Int32>.allocate(capacity: 1); fault.initialize(to: 0)
        let meter = UnsafeMutablePointer<Int32>.allocate(capacity: 4); meter.initialize(repeating: 0, count: 4)
        routes[source.id] = Route(tap: tap, device: 0, io: nil, gain: parameter, fault: fault, meter: meter)
        do {
            let format: AudioStreamBasicDescription = try scalar(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            guard Self.supported(format), format.mSampleRate == outputFormat.mSampleRate else {
                throw QuickUtilityError.unavailable("La señal y la salida no tienen un formato estéreo compatible; se conserva el sonido original.")
            }
            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "ZEUVE · audio temporal",
                kAudioAggregateDeviceUIDKey: "com.zeuve.audio.\(UUID().uuidString)",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]],
                kAudioAggregateDeviceTapAutoStartKey: true
            ]
            try check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate))
            routes[source.id]?.device = aggregate
            let inputs = try objects(aggregate, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            let outputs = try objects(aggregate, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
            guard inputs.count == 1, outputs.count == 1 else { throw QuickUtilityError.unavailable("La ruta agregada tiene canales inesperados; se conserva la salida original.") }
            let inputFormat: AudioStreamBasicDescription = try scalar(inputs[0], kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
            let aggregateOutputFormat: AudioStreamBasicDescription = try scalar(outputs[0], kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
            guard Self.supported(inputFormat), Self.supported(aggregateOutputFormat), inputFormat.mSampleRate == aggregateOutputFormat.mSampleRate else {
                throw QuickUtilityError.unavailable("La ruta agregada no ofrece un formato reproducible seguro.")
            }
            let gainAddress = Int(bitPattern: parameter), faultAddress = Int(bitPattern: fault), meterAddress = Int(bitPattern: meter)
            try check(AudioDeviceCreateIOProcIDWithBlock(&io, aggregate, nil) { _, input, _, output, _ in
                guard let parameter = UnsafeMutablePointer<Int32>(bitPattern: gainAddress), let fault = UnsafeMutablePointer<Int32>(bitPattern: faultAddress), let meter = UnsafeMutablePointer<Int32>(bitPattern: meterAddress) else { return }
                let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
                // Complete output buffers are always initialized, including unexpected HAL layouts.
                for buffer in outputBuffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                // Accept the two public Float32 stereo layouts without changing either device:
                // one interleaved buffer or two mono buffers. Never copy microphone channels.
                guard (inputBuffers.count == 1 || inputBuffers.count == 2), (outputBuffers.count == 1 || outputBuffers.count == 2) else {
                    _ = OSAtomicCompareAndSwap32Barrier(0, 1, fault); return
                }
                let inputStride = inputBuffers.count == 1 ? 2 : 1
                let outputStride = outputBuffers.count == 1 ? 2 : 1
                let frames = Int(inputBuffers[0].mDataByteSize) / (inputStride * 4)
                guard frames > 0,
                      inputBuffers.allSatisfy({ $0.mNumberChannels == UInt32(inputStride) && Int($0.mDataByteSize) == frames * inputStride * 4 && $0.mData != nil }),
                      outputBuffers.allSatisfy({ $0.mNumberChannels == UInt32(outputStride) && Int($0.mDataByteSize) == frames * outputStride * 4 && $0.mData != nil }),
                      let inputLeft = inputBuffers[0].mData?.assumingMemoryBound(to: Float.self),
                      let outputLeft = outputBuffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                    _ = OSAtomicCompareAndSwap32Barrier(0, 1, fault); return
                }
                let inputRight = inputStride == 2 ? inputLeft.advanced(by: 1) : inputBuffers[1].mData!.assumingMemoryBound(to: Float.self)
                let outputRight = outputStride == 2 ? outputLeft.advanced(by: 1) : outputBuffers[1].mData!.assumingMemoryBound(to: Float.self)
                let rawTarget = OSAtomicAdd32Barrier(0, parameter)
                let multiplier = Float(rawTarget) / 1_000_000
                let current = Float(OSAtomicAdd32Barrier(0, parameter.advanced(by: 1))) / 1_000_000
                AudioGainProcessor.renderStereo(inputLeft: inputLeft, inputRight: inputRight, inputStride: inputStride, outputLeft: outputLeft, outputRight: outputRight, outputStride: outputStride, frames: frames, from: current, to: multiplier)
                if OSAtomicAdd32Barrier(0, parameter.advanced(by: 2)) != 0 {
                    let rms = AudioGainProcessor.measureStereo(inputLeft: inputLeft, inputRight: inputRight, inputStride: inputStride, outputLeft: outputLeft, outputRight: outputRight, outputStride: outputStride, frames: frames)
                    if rms.input.isFinite && rms.output.isFinite {
                        _ = OSAtomicIncrement32Barrier(meter)
                        let inputBits = Int32(bitPattern: rms.input.bitPattern), outputBits = Int32(bitPattern: rms.output.bitPattern)
                        let oldInput = OSAtomicAdd32Barrier(0, meter.advanced(by: 1)), oldOutput = OSAtomicAdd32Barrier(0, meter.advanced(by: 2))
                        _ = OSAtomicCompareAndSwap32Barrier(oldInput, inputBits, meter.advanced(by: 1))
                        _ = OSAtomicCompareAndSwap32Barrier(oldOutput, outputBits, meter.advanced(by: 2))
                        _ = OSAtomicIncrement32Barrier(meter.advanced(by: 3))
                        _ = OSAtomicIncrement32Barrier(meter)
                    } else {
                        for buffer in outputBuffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                        _ = OSAtomicCompareAndSwap32Barrier(0, 1, fault)
                    }
                }
                let prior = OSAtomicAdd32Barrier(0, parameter.advanced(by: 1))
                _ = OSAtomicCompareAndSwap32Barrier(prior, rawTarget, parameter.advanced(by: 1))
            })
            guard let io else { throw QuickUtilityError.failure("Core Audio no creó el callback de reproducción.") }
            routes[source.id]?.io = io
            try Task.checkCancellation()
            try check(AudioDeviceStart(aggregate, io))
            routes[source.id] = Route(tap: tap, device: aggregate, io: io, gain: parameter, fault: fault, meter: meter)
            startHealthCheck()
        } catch {
            do { try await stopRoute(sourceID: source.id) }
            catch { throw QuickUtilityError.failure("No se pudo verificar la liberación completa de la ruta de audio. Vuelve a detener el mezclador.") }
            throw error
        }
    }
    public func setGain(sourceID: String, gain: Float) async throws {
        guard gain.isFinite, (0...1).contains(gain), let route = routes[sourceID] else { throw QuickUtilityError.failure("La ruta de audio ya no existe.") }
        let replacement = Int32((gain * 1_000_000).rounded())
        var previous = OSAtomicAdd32Barrier(0, route.gain)
        while !OSAtomicCompareAndSwap32Barrier(previous, replacement, route.gain) { previous = OSAtomicAdd32Barrier(0, route.gain) }
    }
    public func setMeteringEnabled(sourceID: String, enabled: Bool) async throws {
        guard let route = routes[sourceID] else { throw QuickUtilityError.failure("La ruta de prueba ya no está disponible.") }
        let pointer = route.gain.advanced(by: 2)
        let previous = OSAtomicAdd32Barrier(0, pointer)
        _ = OSAtomicCompareAndSwap32Barrier(previous, enabled ? 1 : 0, pointer)
    }
    public func readMeters() async throws -> [AudioRouteMeter] {
        var result: [AudioRouteMeter] = []
        for (id, route) in routes where OSAtomicAdd32Barrier(0, route.gain.advanced(by: 2)) != 0 {
            // Sequence lock: bounded retries, no blocking of the real-time writer.
            for _ in 0..<3 {
                let before = OSAtomicAdd32Barrier(0, route.meter)
                guard before & 1 == 0 else { continue }
                let input = Float(bitPattern: UInt32(bitPattern: OSAtomicAdd32Barrier(0, route.meter.advanced(by: 1))))
                let output = Float(bitPattern: UInt32(bitPattern: OSAtomicAdd32Barrier(0, route.meter.advanced(by: 2))))
                let count = UInt32(bitPattern: OSAtomicAdd32Barrier(0, route.meter.advanced(by: 3)))
                if before == OSAtomicAdd32Barrier(0, route.meter), count > 0 {
                    result.append(.init(id: id, inputRMS: input, outputRMS: output, callbackCount: count)); break
                }
            }
        }
        return result
    }
    public func stopRoute(sourceID: String) async throws {
        guard #available(macOS 14.2, *), var route = routes[sourceID] else { return }
        // Preserve the handle on failure so later stop attempts can retry rather than losing ownership.
        if let io = route.io {
            try check(AudioDeviceStop(route.device, io))
            try check(AudioDeviceDestroyIOProcID(route.device, io))
            route.io = nil; routes[sourceID] = route
        }
        if route.device != 0 {
            try check(AudioHardwareDestroyAggregateDevice(route.device))
            route.device = 0; routes[sourceID] = route
        }
        if route.tap != 0 {
            try check(AudioHardwareDestroyProcessTap(route.tap))
            route.tap = 0; routes[sourceID] = route
        }
        route.meter.deinitialize(count: 4); route.meter.deallocate()
        route.gain.deinitialize(count: 3); route.gain.deallocate(); route.fault.deinitialize(count: 1); route.fault.deallocate()
        routes.removeValue(forKey: sourceID)
        if routes.isEmpty { healthTask?.cancel(); healthTask = nil }
    }
    public func stopAll() async throws {
        var first: Error?
        for id in Array(routes.keys) { do { try await stopRoute(sourceID: id) } catch { if first == nil { first = error } } }
        if let first { throw first }
    }
    public func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws {
        self.handler = handler
        if handler == nil {
            eventContinuation?.finish(); eventContinuation = nil
            let pending = eventTask; pending?.cancel()
            if let pending { await pending.value }
            eventTask = nil
        } else if eventTask == nil {
            let (stream, continuation) = AsyncStream.makeStream(of: NativeEvent.self, bufferingPolicy: .bufferingNewest(16))
            eventContinuation = continuation
            eventTask = Task { [weak self] in
                for await event in stream {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .changed(let force): await self?.nativeChange(force: force)
                    case .sleeping: await self?.sleeping()
                    }
                }
            }
        }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver); self.sleepObserver = nil }
        var first: Error?
        var remaining: [Listener] = []
        for var listener in listeners {
            do { try check(AudioObjectRemovePropertyListenerBlock(listener.object, &listener.address, nil, listener.block)) }
            catch { remaining.append(listener); if first == nil { first = error } }
        }
        listeners = remaining
        if let first { throw first }
        guard handler != nil else { return }
        do {
            let continuation = eventContinuation
            sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
                continuation?.yield(.sleeping)
            }
            observedSources = try await discoverSources()
            observedOutput = try scalar(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, initial: 0)
            if observedOutput != 0 {
                try addListener(observedOutput, kAudioDevicePropertyDeviceIsAlive, force: true)
                try addListener(observedOutput, kAudioDevicePropertyNominalSampleRate, force: true)
                for stream in try objects(observedOutput, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput) {
                    try addListener(stream, kAudioStreamPropertyVirtualFormat, force: true)
                }
            }
            try addListener(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice)
            try addListener(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
            let processes = try objects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
            for object in processes {
                try addListener(object, kAudioProcessPropertyIsRunningInput)
                try addListener(object, kAudioProcessPropertyIsRunningOutput)
            }
        } catch {
            // Do not join the event consumer from inside its own rearm operation. The external
            // owner calls observeChanges(nil) and joins it when handling this failure.
            eventContinuation?.finish(); eventTask?.cancel()
            throw error
        }
    }
    private func addListener(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, force: Bool = false) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let continuation = eventContinuation
        let block: AudioObjectPropertyListenerBlock = { _, _ in continuation?.yield(.changed(force)) }
        try check(AudioObjectAddPropertyListenerBlock(object, &address, nil, block))
        listeners.append(Listener(object: object, address: address, block: block))
    }
    private func nativeChange(force: Bool) async {
        guard let handler else { return }
        do {
            let sources = try await discoverSources()
            let output: AudioObjectID = try scalar(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, initial: 0)
            guard force || sources != observedSources || output != observedOutput else { return }
            try await observeChanges(handler)
            await handler(nil)
        } catch { await handler("No se pudo revalidar la fuente o la salida de audio; se restaura el sonido original.") }
    }
    private func sleeping() async {
        guard let handler else { return }
        do { try await stopAll() }
        catch { await handler("No se pudo verificar la retirada de la ruta al suspender el Mac."); return }
        await handler("La suspensión ha detenido las rutas de audio. Vuelve a activar el mezclador al reanudar.")
    }
    private func startHealthCheck() {
        guard healthTask == nil else { return }
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                await self?.checkHealth()
            }
        }
    }
    private func checkHealth() async {
        if routes.values.contains(where: { OSAtomicAdd32Barrier(0, $0.fault) != 0 }), let handler {
            await handler("La ruta cambió de formato; se detiene el procesamiento y se recupera la salida original.")
        }
    }
    private static func supported(_ format: AudioStreamBasicDescription) -> Bool {
        format.mFormatID == kAudioFormatLinearPCM && format.mFormatFlags & kAudioFormatFlagIsFloat != 0 && format.mBitsPerChannel == 32 && format.mChannelsPerFrame == 2 && format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 && format.mSampleRate.isFinite && format.mSampleRate > 0
    }
    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            if status == kAudioDevicePermissionsError { throw QuickUtilityError.requiresPermission(.audioCapture) }
            throw QuickUtilityError.failure("Core Audio devolvió el error técnico \(status).")
        }
    }
    private func scalar<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value = initial, size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutablePointer(to: &value) { try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)) }
        return value
    }
    private func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String? {
        let value: CFString? = try scalar(object, selector, initial: Optional<CFString>.none)
        return value.map { $0 as String }
    }
    private func objects(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> [UInt32] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size))
        guard size % 4 == 0, size <= 1_048_576 else { throw QuickUtilityError.failure("Core Audio devolvió una lista de tamaño no válido.") }
        var values = [UInt32](repeating: 0, count: Int(size / 4))
        guard size > 0 else { return values }
        try values.withUnsafeMutableBytes { try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0.baseAddress!)) }
        return Array(values.prefix(Int(size / 4)))
    }
    #else
    public init(ownBundleID: String = "com.zeuve.app") {}
    public func discoverSources() async throws -> [AudioApplicationSource] { throw QuickUtilityError.unavailable("Core Audio necesita macOS.") }
    public func startRoute(source: AudioApplicationSource, gain: Float) async throws { throw QuickUtilityError.unavailable("Core Audio necesita macOS.") }
    public func setGain(sourceID: String, gain: Float) async throws { throw QuickUtilityError.unavailable("Core Audio necesita macOS.") }
    public func stopRoute(sourceID: String) async throws {}
    public func stopAll() async throws {}
    public func setMeteringEnabled(sourceID: String, enabled: Bool) async throws { throw QuickUtilityError.unavailable("Core Audio necesita macOS.") }
    public func readMeters() async throws -> [AudioRouteMeter] { throw QuickUtilityError.unavailable("Core Audio necesita macOS.") }
    public func observeChanges(_ handler: (@MainActor @Sendable (String?) -> Void)?) async throws {}
    #endif
}

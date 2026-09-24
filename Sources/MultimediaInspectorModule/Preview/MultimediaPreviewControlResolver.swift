import Foundation

public enum MultimediaPreviewControlAction: Sendable, Equatable {
    case start
    case pause
    case resume
    case restart
    case wait
}

public struct MultimediaPreviewControlResolution: Sendable, Equatable {
    public let state: MultimediaPreviewPlaybackState
    public let action: MultimediaPreviewControlAction

    public init(state: MultimediaPreviewPlaybackState, action: MultimediaPreviewControlAction) {
        self.state = state
        self.action = action
    }
}

/// Proyecta una sesión compartida sobre un control de pista concreto. La identidad
/// solicitada prevalece durante una sustitución; después solo cuenta la identidad
/// confirmada por el servicio.
public enum MultimediaPreviewControlResolver {
    public static func resolve(
        targetSourceID: String?,
        requestedSourceID: String?,
        confirmedSourceID: String?,
        transportState: MultimediaPreviewPlaybackState
    ) -> MultimediaPreviewControlResolution {
        guard let targetSourceID else {
            return .init(state: .idle, action: .start)
        }

        if let requestedSourceID {
            if requestedSourceID == targetSourceID {
                return .init(state: .loading, action: .wait)
            }
            return .init(state: .idle, action: .start)
        }

        guard confirmedSourceID == targetSourceID else {
            return .init(state: .idle, action: .start)
        }

        switch transportState {
        case .playing:
            return .init(state: .playing, action: .pause)
        case .loading:
            return .init(state: .loading, action: .wait)
        case .paused:
            return .init(state: .paused, action: .resume)
        case .finished:
            return .init(state: .finished, action: .restart)
        case .idle, .failed:
            return .init(state: .idle, action: .start)
        }
    }
}

public enum MultimediaPreviewSessionOwnership: Sendable, Equatable {
    case noSession
    case originalOnly
    case containsExternalOrUnavailable
}

/// Clasifica todos los componentes activos o solicitados antes de descartar un
/// borrador. Una sesión solo se conserva cuando cada identidad pertenece al
/// archivo original; una mezcla o una identidad desconocida se limpia completa.
public enum MultimediaPreviewSessionOwnershipResolver {
    public static func resolve(
        hasSession: Bool,
        sourceIDs: Set<String>,
        originalSourceIDs: Set<String>
    ) -> MultimediaPreviewSessionOwnership {
        guard hasSession else { return .noSession }
        guard !sourceIDs.isEmpty, sourceIDs.allSatisfy(originalSourceIDs.contains) else {
            return .containsExternalOrUnavailable
        }
        return .originalOnly
    }
}

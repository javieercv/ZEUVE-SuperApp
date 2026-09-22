import Foundation
public struct CleanerOfficialUninstaller:Sendable,Equatable{public let url:URL;public let reason:String}
public struct CleanerOfficialUninstallerDetector:Sendable{
    let identityProvider:any CleanerAppIdentityProviding
    public init(identityProvider:any CleanerAppIdentityProviding=SystemCleanerAppIdentityProvider()){self.identityProvider=identityProvider}
    public func detect(for app:CleanerAppInventoryItem)->CleanerOfficialUninstaller?{
        let appURL=URL(fileURLWithPath:app.identity.path);let roots=[appURL.deletingLastPathComponent(),appURL.appendingPathComponent("Contents/Resources")]
        for root in roots{guard let items=try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil) else{continue};for url in items where url.pathExtension.lowercased()=="app" && url.lastPathComponent.localizedCaseInsensitiveContains("uninstall"){
            guard let identity=identityProvider.identity(for:url) else{continue};if let team=app.identity.teamID,identity.teamID != team{continue};return .init(url:url,reason:"Desinstalador relacionado por ubicación y firma/equipo cuando está disponible.")
        }};return nil
    }
}

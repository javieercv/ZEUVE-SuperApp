import Foundation
public enum CleanerPlanner{
    public static func plan(candidates:[CleanerCandidate],selectSafeItems:Bool)->CleanerRemovalPlan{.init(candidates:candidates.map{copy($0,selected:selectSafeItems && $0.canBeSafelyPreselected)})}
    public static func settingSelection(_ selected:Bool,candidateID:UUID,in plan:CleanerRemovalPlan)->CleanerRemovalPlan{.init(candidates:plan.candidates.map{$0.id==candidateID ? copy($0,selected:selected && canSelect($0)):$0})}
    public static func canSelect(_ c:CleanerCandidate)->Bool{!c.isShared && !c.requiresAdministrator && !c.applicationRunning && c.status != .applicationUnavailable && c.status != .keptByUser}
    public static func copy(_ c:CleanerCandidate,selected:Bool)->CleanerCandidate{.init(id:c.id,url:c.url,category:c.category,associatedAppName:c.associatedAppName,associatedBundleID:c.associatedBundleID,evidences:c.evidences,confidence:c.confidence,status:c.status,risk:c.risk,logicalSize:c.logicalSize,allocatedSize:c.allocatedSize,containsPotentialUserData:c.containsPotentialUserData,isShared:c.isShared,requiresAdministrator:c.requiresAdministrator,applicationRunning:c.applicationRunning,consequence:c.consequence,selected:selected,fingerprint:c.fingerprint)}
}

import Foundation

#if DEBUG
enum TestServiceRetainer {
    private static var retainedObjects: [AnyObject] = []

    static func retain(_ object: AnyObject) {
        retainedObjects.append(object)
    }
}
#endif

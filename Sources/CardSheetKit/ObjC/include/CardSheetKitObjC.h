#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`, catching an Objective-C exception instead of crashing; returns it, or nil.
/// Swift cannot catch NSExceptions, and private UIKit can raise them for a missing selector.
NSException *_Nullable CardSheetKitTry(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END

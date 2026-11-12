#import "CardSheetKitObjC.h"

NSException *_Nullable CardSheetKitTry(NS_NOESCAPE void (^block)(void)) {
  @try {
    block();
    return nil;
  } @catch (NSException *exception) {
    return exception;
  }
}

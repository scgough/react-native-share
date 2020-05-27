//
//  InstagramShare.m
//  RNShare
//
//  Created by Ralf Nieuwenhuizen on 12-04-17.
//

#import "InstagramShare.h"
#import <AVFoundation/AVFoundation.h>
@import Photos;

@implementation InstagramShare
    RCT_EXPORT_MODULE();
- (void)shareSingle:(NSDictionary *)options
    failureCallback:(RCTResponseErrorBlock)failureCallback
    successCallback:(RCTResponseSenderBlock)successCallback {
    
    NSLog(@"Try open view");

    __block NSString * stringURL = options[@"url"];
    NSURL * testURL = [NSURL URLWithString: stringURL];
    
    if([testURL.scheme.lowercaseString isEqualToString:@"ph"]) {
        NSString *assetIdentifier = [stringURL stringByReplacingOccurrencesOfString: @"ph://" withString: @""];
        
        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers: @[assetIdentifier] options:nil];
        PHAsset *asset = fetchResult.firstObject;
        
        if (asset){
            switch(asset.mediaType) {
                case PHAssetMediaTypeImage: {
                    stringURL = [NSString stringWithFormat:@"assets-library://asset/asset.jpeg?id=%@", assetIdentifier];
                    break;
                }
                case PHAssetMediaTypeVideo: {
                    stringURL = [NSString stringWithFormat:@"assets-library://asset/asset.mp4?id=%@", assetIdentifier];
                    break;
                }
                default: {
                    RCTLogError(@"Asset type can't be shared");
                    return;
                }
            }
            
        }
    }
    
    NSURL * fileURL = [NSURL URLWithString: stringURL];
    
    AVURLAsset* videoAsset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    CMTime videoDuration = videoAsset.duration;
    float videoDurationSeconds = CMTimeGetSeconds(videoDuration);

    NSLog(@"Video duration: %f seconds for file %@", videoDurationSeconds, videoAsset.URL.absoluteString);
        
    NSURL * shareURL;
    // Instagram doesn't allow sharing videos longer than 60 seconds on iOS anymore. (next button is not responding, trim is unavailable)
    if (videoDurationSeconds <= 60.0f) {
        NSString * urlString = [NSString stringWithFormat:@"instagram://library?AssetPath=%@", stringURL];
        shareURL = [NSURL URLWithString:urlString];
    } else {
        shareURL = [NSURL URLWithString:@"instagram://camera"];
    }
    
    if ([[UIApplication sharedApplication] canOpenURL: shareURL]) {
        [[UIApplication sharedApplication] openURL: shareURL];
        successCallback(@[]);
    } else {
        // Cannot open instagram
        NSString *stringURL = @"https://itunes.apple.com/app/instagram/id389801252";
        NSURL *url = [NSURL URLWithString:stringURL];
        
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {}];
        
        NSString *errorMessage = @"Not installed";
        NSDictionary *userInfo = @{NSLocalizedFailureReasonErrorKey: NSLocalizedString(errorMessage, nil)};
        NSError *error = [NSError errorWithDomain:@"com.rnshare" code:1 userInfo:userInfo];
        
        NSLog(@"%@", errorMessage);
        failureCallback(error);
    }
}

- (void)shareSingleImage:(NSDictionary *)options
         failureCallback:(RCTResponseErrorBlock)failureCallback
         successCallback:(RCTResponseSenderBlock)successCallback {
    
    UIImage *image;
    NSURL *imageURL = [RCTConvert NSURL:options[@"url"]];
    if (imageURL) {
        if (imageURL.fileURL || [imageURL.scheme.lowercaseString isEqualToString:@"data"]) {
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:imageURL
                                                 options:(NSDataReadingOptions)0
                                                   error:&error];
            if (!data) {
                failureCallback(error);
                return;
            }
            image = [UIImage imageWithData: data];
            [self savePictureAndOpenInstagram: image
                              failureCallback: failureCallback
                              successCallback: successCallback];
        }
    } else {
        [[UIApplication sharedApplication] openURL: [NSURL URLWithString:@"instagram://camera"]];
        successCallback(@[]);
    }
}

-(void)savePictureAndOpenInstagram:(UIImage *)base64Image
                   failureCallback:(RCTResponseErrorBlock)failureCallback
                   successCallback:(RCTResponseSenderBlock)successCallback {
    
    NSURL *URL = [self fileURLWithTemporaryImageData:UIImageJPEGRepresentation(base64Image, 0.9)];
    __block PHAssetChangeRequest *_mChangeRequest = nil;
    __block PHObjectPlaceholder *placeholder;
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        NSData *pngData = [NSData dataWithContentsOfURL:URL];
        UIImage *image = [UIImage imageWithData:pngData];
        _mChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        placeholder = _mChangeRequest.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        
        if (success) {
            NSURL *instagramURL = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://library?LocalIdentifier=\%@", [placeholder localIdentifier]]];
            
            if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
                if (@available(iOS 10.0, *)) {
                    [[UIApplication sharedApplication] openURL:instagramURL options:@{} completionHandler:NULL];
                }
                if (successCallback != NULL) {
                    successCallback(@[]);
                }
            }
        }
        else {
            //Error while writing
            if (failureCallback != NULL) {
                failureCallback(error);
            }
        }
    }];
}

- (NSURL *)fileURLWithTemporaryImageData:(NSData *)data {
    NSString *writePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"instagram.ig"];
    if (![data writeToFile:writePath atomically:YES]) {
        return nil;
    }
    return [NSURL fileURLWithPath:writePath];
}

@end
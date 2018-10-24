//
//  VCVTH264Encoder.h
//  VideoCodecKit
//
//  Created by CmST0us on 2018/10/23.
//  Copyright © 2018 eric3u. All rights reserved.
//

#import "VCBaseEncoder.h"

@interface VCVTH264Encoder : VCBaseEncoder

/**
 使用sps

 @param spsData sps数据，注意不带start code
 */
- (void)useSPS:(NSData *)spsData;
/**
 使用pps
 
 @param spsData pps数据，注意不带start code
 */
- (void)usePPS:(NSData *)ppsData;

@end

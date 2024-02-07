/*
 * Copyright (C) 2024 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "VideoPresentationInterfaceLMK.h"

#if PLATFORM(VISION)

#import "PlaybackSessionInterfaceLMK.h"
#import <LinearMediaKit/LinearMediaKit.h> // FIXME: need an SPI header
#import <UIKit/UIKit.h>
#import <WebCore/WebAVPlayerLayerView.h>
#import <WebKitSwift/WebKitSwift.h>

@interface WKPlayableViewControllerDelegate : NSObject <LMPlayableViewControllerDelegate>
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithInterface:(WebKit::VideoPresentationInterfaceLMK&)interface;
@end

@implementation WKPlayableViewControllerDelegate {
    ThreadSafeWeakPtr<WebKit::VideoPresentationInterfaceLMK> _interface;
}

- (instancetype)initWithInterface:(WebKit::VideoPresentationInterfaceLMK&)interface
{
    self = [super init];
    if (!self)
        return nil;

    _interface = interface;
    return self;
}

@end

namespace WebKit {

VideoPresentationInterfaceLMK::~VideoPresentationInterfaceLMK()
{
}

Ref<VideoPresentationInterfaceLMK> VideoPresentationInterfaceLMK::create(PlaybackSessionInterfaceIOS& playbackSessionInterface)
{
    return adoptRef(*new VideoPresentationInterfaceLMK(playbackSessionInterface));
}

VideoPresentationInterfaceLMK::VideoPresentationInterfaceLMK(PlaybackSessionInterfaceIOS& playbackSessionInterface)
    : VideoPresentationInterfaceIOS { playbackSessionInterface }
    , m_playerViewControllerDelegate { adoptNS([[WKPlayableViewControllerDelegate alloc] initWithInterface:*this]) }
{
}

WKSLinearMediaPlayer *VideoPresentationInterfaceLMK::linearMediaPlayer() const
{
    return playbackSessionInterface().linearMediaPlayer();
}

void VideoPresentationInterfaceLMK::setupFullscreen(UIView& videoView, const FloatRect& initialRect, const FloatSize& videoDimensions, UIView* parentView, HTMLMediaElementEnums::VideoFullscreenMode mode, bool allowsPictureInPicturePlayback, bool standby, bool blocksReturnToFullscreenFromPictureInPicture)
{
    linearMediaPlayer().contentDimensions = videoDimensions;

    VideoPresentationInterfaceIOS::setupFullscreen(videoView, initialRect, videoDimensions, parentView, mode, allowsPictureInPicturePlayback, standby, blocksReturnToFullscreenFromPictureInPicture);
}

bool VideoPresentationInterfaceLMK::pictureInPictureWasStartedWhenEnteringBackground() const
{
    return false;
}

void VideoPresentationInterfaceLMK::hasVideoChanged(bool)
{
    
}

void VideoPresentationInterfaceLMK::setPlayerIdentifier(std::optional<MediaPlayerIdentifier> identifier)
{
    VideoPresentationInterfaceIOS::setPlayerIdentifier(identifier);
}

bool VideoPresentationInterfaceLMK::mayAutomaticallyShowVideoPictureInPicture() const
{
    return false;
}

void VideoPresentationInterfaceLMK::setupPlayerViewController()
{
    if (!m_playerViewController)
        m_playerViewController = [linearMediaPlayer() makeViewController];

    [m_playerViewController setDelegate:m_playerViewControllerDelegate.get()];

    linearMediaPlayer().allowFullScreenFromInline = YES;
    linearMediaPlayer().contentType = WKSLinearMediaContentTypePlanar;
    linearMediaPlayer().presentationMode = WKSLinearMediaPresentationModeInline;
    linearMediaPlayer().showsPlaybackControls = YES;
    linearMediaPlayer().videoLayer = [m_playerLayerView playerLayer];
    
}

void VideoPresentationInterfaceLMK::invalidatePlayerViewController()
{
    [m_playerViewController setDelegate:nil];
    [linearMediaPlayer() detachFromViewController:m_playerViewController.get()];
    m_playerViewController = nil;
}

void VideoPresentationInterfaceLMK::presentFullscreen(bool animated, CompletionHandler<void(BOOL, NSError *)>&& completionHandler)
{
    RetainPtr presentingViewController = this->presentingViewController();
    if (!presentingViewController) {
        completionHandler(NO, nil);
        return;
    }

    m_presentingViewController = WTFMove(presentingViewController);
//    [m_playerViewController view].frame = [m_presentingViewController view].frame;
    [m_presentingViewController presentViewController:fullscreenViewController() animated:animated completion:makeBlockPtr([completionHandler = WTFMove(completionHandler)]() mutable {
        completionHandler(YES, nil);
    }).get()];
}

void VideoPresentationInterfaceLMK::dismissFullscreen(bool animated, CompletionHandler<void(BOOL, NSError *)>&& completionHandler)
{
    if (!m_presentingViewController) {
        completionHandler(NO, nil);
        return;
    }

    [std::exchange(m_presentingViewController, nullptr) dismissViewControllerAnimated:animated completion:makeBlockPtr([completionHandler = WTFMove(completionHandler)]() mutable {
        completionHandler(YES, nil);
    }).get()];
}

bool VideoPresentationInterfaceLMK::isPlayingVideoInEnhancedFullscreen() const
{
    return false;
}

AVPlayerViewController *VideoPresentationInterfaceLMK::avPlayerViewController() const
{
    return nullptr;
}

UIViewController *VideoPresentationInterfaceLMK::playerViewController() const
{
    return m_playerViewController.get();
}

void VideoPresentationInterfaceLMK::setContentDimensions(const FloatSize& contentDimensions)
{
    linearMediaPlayer().contentDimensions = contentDimensions;
}

void VideoPresentationInterfaceLMK::setShowsPlaybackControls(bool)
{
//    linearMediaPlayer().showsPlaybackControls = showsPlaybackControls;
}

} // namespace WebKit

#endif // PLATFORM(VISION)

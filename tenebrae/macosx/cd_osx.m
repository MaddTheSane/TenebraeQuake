//----------------------------------------------------------------------------------------------------------------------------
//
// "cd_osx.m" - MacOS X audio CD driver.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				�2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake� is copyrighted by id software		[http://www.idsoftware.com].
//
// Version History:
// v1.2.0: Rewritten. Uses now AudioGraph/AudioUnit for playback.
// v1.0.9: Rewritten. Uses now QuickTime for playback. Added support for MP3 and MP4 [AAC] playback.
// v1.0.3: Fixed an issue with requesting a track number greater than the max number.
// v1.0.1: Added "cdda" as extension for detection of audio-tracks [required by MacOS X v10.1 or later]
// v1.0.0: Initial release.
//
//----------------------------------------------------------------------------------------------------------------------------

#import "cd_osx.h"

#import "quakedef.h"
#import "QController.h"

#import <FruitzOfDojo/FruitzOfDojo.h>

#import <sys/mount.h>

//----------------------------------------------------------------------------------------------------------------------------

static FDAudioFile*     sCDAudio            = nil;
static NSString*        sCDAudioMountPath   = nil;
static NSMutableArray*	sCDAudioTrackList   = nil;
static NSUInteger       sCDAudioTrack       = 0;

//----------------------------------------------------------------------------------------------------------------------------

static void     CDAudio_AddTracks2List (NSString* mountPath, NSArray* extensions, NSConditionLock* stopConditionLock);
static void     CD_f (void);

//----------------------------------------------------------------------------------------------------------------------------

int	CDAudio_Init (void)
{
    int success = 0;
    
    Cmd_AddCommand ("mp3", CD_f);
    Cmd_AddCommand ("mp4", CD_f);
    Cmd_AddCommand ("cd", CD_f);
    
    sCDAudioTrack       = 0;
    sCDAudio            = [[FDAudioFile alloc] initWithMixer: [FDAudioMixer sharedAudioMixer]];
    
    [[FDAudioMixer sharedAudioMixer] start];
    
    if (sCDAudio != nil)
    {
        if (sCDAudioTrackList == nil)
        {
            Con_Print ("CD driver: no audio tracks!\n");
        }
        
        Con_Print ("CD driver initialized...\n");
        
        success = 1;
    }
    else
    {
        Con_Print ("Failed to initialize CD driver!\n");
        
    }
    
    return success;
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Shutdown (void)
{
    [sCDAudio release];
    [sCDAudioMountPath release];
    [sCDAudioTrackList release];

    sCDAudio            = nil;
    sCDAudioMountPath   = nil;
    sCDAudioTrackList   = nil;
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_AddTracks2List (NSString* mountPath, NSArray* extensions, NSConditionLock* stopConditionLock)
{
    NSFileManager*          fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator*  dirEnum     = [fileManager enumeratorAtPath: mountPath];
        
    if (dirEnum != nil)
    {
        NSUInteger  extensionCount  = [extensions count];
        NSString*   filePath        = nil;

        Con_Print ("Scanning for audio tracks. Be patient!\n");
        
        while ((filePath = [dirEnum nextObject]))
        {
            if (stopConditionLock != nil)
            {
                [stopConditionLock lock];
                
                const BOOL doStop = ([stopConditionLock condition] != 0);
                
                [stopConditionLock unlock];
                
                if (doStop == YES)
                {
                    break;
                }
            }

            for (NSUInteger i = 0; i < extensionCount; ++i)
            {
                if ([[filePath pathExtension] isEqualToString: [extensions objectAtIndex: i]])
                {
                    NSString*   fullPath = [mountPath stringByAppendingPathComponent: filePath];

                    [sCDAudioTrackList addObject: [NSURL fileURLWithPath: fullPath]];
                }
            }
        }
    }
        
    sCDAudioMountPath = [[NSString alloc] initWithString: mountPath];
}

//----------------------------------------------------------------------------------------------------------------------------

BOOL	CDAudio_ScanForMedia (NSString* mediaFolder, NSConditionLock* stopConditionLock)
{
    NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
    
    [sCDAudioMountPath release];
    [sCDAudioTrackList release];
    
    sCDAudioMountPath   = nil;
    sCDAudioTrackList   = [[NSMutableArray alloc] init];
    sCDAudioTrack       = 0;
    
    // Get the current MP3 listing or retrieve the TOC of the AudioCD:
    if (mediaFolder != nil)
    {        
        CDAudio_AddTracks2List (mediaFolder, [NSArray arrayWithObjects: @"mp3", @"mp4", @"m4a", nil], stopConditionLock);
    }
    else
    {
        struct statfs*  mountList = 0;
        UInt32			mountCount = getmntinfo (&mountList, MNT_NOWAIT);
        
        while (mountCount--)
        {
            // is the device read only?
            if ((mountList[mountCount].f_flags & MNT_RDONLY) != MNT_RDONLY)
            {
                continue;
            }
            
            // is the device local?
            if ((mountList[mountCount].f_flags & MNT_LOCAL) != MNT_LOCAL)
            {
                continue;
            }
            
            // is the device "cdda"?
            if (strcmp (mountList[mountCount].f_fstypename, "cddafs"))
            {
                continue;
            }
            
            // is the device a directory?
            if (strrchr (mountList[mountCount].f_mntonname, '/') == NULL)
            {
                continue;
            }
            
            mediaFolder = [NSString stringWithCString: mountList[mountCount].f_mntonname encoding: NSASCIIStringEncoding];
            
            CDAudio_AddTracks2List (mediaFolder, [NSArray arrayWithObjects: @"aiff", @"cdda", nil], stopConditionLock);
            
            break;
        }
    }

    [pool release];
    
    if ([sCDAudioTrackList count] == 0)
    {
        [sCDAudioTrackList release];
        sCDAudioTrackList = nil;
        
        Con_Print ("CDAudio: No audio tracks found!\n");
        
        return NO;
    }
    
    return YES;
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Play (byte track, qboolean loop)
{
    if (sCDAudio != nil)
    {
        if ((track <= 0) || (track > [sCDAudioTrackList count]))
        {
            track = 1;
        }
        
        if (sCDAudioTrackList != nil)
        {
            if ([sCDAudio startFile: [sCDAudioTrackList objectAtIndex: track - 1] loop: (loop != false)])
            {
                sCDAudioTrack = track;
            }
            else
            {
                Con_Print ("CDAudio: Failed to start playback!\n");
            }
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Stop (void)
{
    if (sCDAudio != nil)
    {
        [sCDAudio stop];
    }
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Pause (void)
{
    if (sCDAudio != nil)
    {
        [sCDAudio pause];
    }
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Resume (void)
{
    if (sCDAudio != nil)
    {
        [sCDAudio resume];
    }
}

//----------------------------------------------------------------------------------------------------------------------------

void	CDAudio_Update (void)
{
    if (sCDAudio != nil)
    {
        [sCDAudio setVolume: bgmvolume.value];
        
        if (([sCDAudio loops] == NO) && ([sCDAudio isFinished] == YES))
        {
            CDAudio_Play (sCDAudioTrack + 1, 0);
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------------

void	CD_f (void)
{
    char*   arg;
    
    // this command requires arguments!
    if (Cmd_Argc () < 2)
    {
        return;
    }
    
    arg = Cmd_Argv (1);
    
    // turn CD playback on:
    if (Q_strcasecmp (arg, "on") == 0)
    {
        if (sCDAudio == nil)
        {
            sCDAudio = [[FDAudioFile alloc] initWithMixer: [FDAudioMixer sharedAudioMixer]];
            
            CDAudio_Play (1, 0);
        }

		return;
    }
    
    if (sCDAudio == nil)
    {
        return;
    }
    
    // turn CD playback off:
    if (Q_strcasecmp (arg, "off") == 0)
    {
        [sCDAudio release];
        sCDAudio = nil;
        
		return;
    }
    
    // just for compatibility:
    if (Q_strcasecmp (arg, "remap") == 0)
    {
        return;
    }
    
    // reset the current CD:
    if (Q_strcasecmp (arg, "reset") == 0)
    {
        CDAudio_Stop ();
        
        if (CDAudio_ScanForMedia ([[NSApp delegate] mediaFolder], nil))
        {
            NSUInteger  numTracks = 0;
            
            if (sCDAudioTrackList != nil)
            {
                numTracks = [sCDAudioTrackList count];
            }
            
            if ([[NSApp delegate] mediaFolder] == nil)
            {
                Con_Print ("CD");
            }
            else
            {
                Con_Print ("Audio files");
            }
            Con_Printf (" found. %d tracks.\n", numTracks);
        }
        
		return;
    }
    
    // the following commands require a valid track array, so build it, if not present:
    if (sCDAudioTrackList == nil)
    {
        if (!CDAudio_ScanForMedia ([[NSApp delegate] mediaFolder], nil))
        {
            return;
        }
    }
    
    // play the selected track:
    if (Q_strcasecmp (arg, "play") == 0)
    {
        CDAudio_Play (atoi (Cmd_Argv (2)), 0);
        
		return;
    }
    
    // loop the selected track:
    if (Q_strcasecmp (arg, "loop") == 0)
    {
        CDAudio_Play (atoi (Cmd_Argv (2)), 1);
        
		return;
    }
    
    // stop the current track:
    if (Q_strcasecmp (arg, "stop") == 0)
    {
        CDAudio_Stop ();
        
		return;
    }
    
    // pause the current track:
    if (Q_strcasecmp (arg, "pause") == 0)
    {
        CDAudio_Pause ();
        
		return;
    }
    
    // resume the current track:
    if (Q_strcasecmp (arg, "resume") == 0)
    {
        CDAudio_Resume ();
        
		return;
    }
    
    // eject the CD:
    if (Q_strcasecmp (arg, "eject") == 0)
    {
        if (([[NSApp delegate] mediaFolder] == nil) && (sCDAudioMountPath != nil))
        {
            NSURL*      url = [NSURL fileURLWithPath: sCDAudioMountPath];
            NSError*    err = nil;
            
            [sCDAudio stop];
            
            if (![[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL: url error: &err])
            {
                Con_Printf ("CDAudio: Failed to eject media!\n");
            }
        }
        else
        {
            Con_Printf ("CDAudio: No media mounted!\n");
        }

		return;
    }
    
    // output CD info:
    if (Q_strcasecmp(arg, "info") == 0)
    {
        if (sCDAudioTrackList == nil)
        {
            Con_Print ("CDAudio: No audio tracks found!\n");
        }
        else
        {
            const NSUInteger    numTracks = [sCDAudioTrackList count];
            const char*         mountPath = [sCDAudioMountPath cStringUsingEncoding: NSASCIIStringEncoding];
            
            if ([sCDAudio isPlaying] == YES)
            {
                Con_Printf ("Playing track %d of %d (\"%s\").\n", sCDAudioTrack, numTracks, mountPath);
            }
            else
            {
                Con_Printf ("Not playing. Tracks: %d (\"%s\").\n", numTracks, mountPath);
            }
 
            Con_Printf ("CD volume is: %.2f.\n", bgmvolume.value);
        }
        
		return;
    }
}

//----------------------------------------------------------------------------------------------------------------------------
